module game_logic(
    input wire rst_n,
    input wire clk, // 60Hz frame clock
    input [2:0] sw,
    input logic [9:0] [19:0] obstacle_x,
    input logic [9:0] [17:0] obstacle_y,
    output reg [1:0] gamemode, // 修改为reg类型以便在always块中赋值
    output reg [8:0] player_y
);

    wire sw_n = ~sw[0]; // Player control switch
    reg [8:0] velocity;
    reg [1:0] crash; // crash状态
    reg velocity_direction; // 0 for up, 1 for down
    
    // Game constants
    parameter UPPER_BOUND   = 20;
    parameter LOWER_BOUND   = 460;
    parameter PLAYER_SIZE   = 40;
    parameter PLAYER_X_LEFT = 160;
    parameter PLAYER_X_RIGHT= 200; // PLAYER_X_LEFT + PLAYER_SIZE
    parameter MAX_VELOCITY  = 10;
    parameter ACCELERATION  = 1;

    // gamemode逻辑：crash状态优先级最高
    always_comb begin
        if (crash == 2'b11) begin
            gamemode = 2'b11; // 崩溃状态优先级最高
        end else begin
            gamemode = sw[2:1]; // 正常情况下跟随开关
        end
    end

    // --- Combinational Logic for next state calculation ---
    wire [8:0] velocity_next;
    wire velocity_direction_next;
    wire [8:0] player_y_next;

    // Velocity and direction logic - 只在gamemode 01时更新
    assign velocity_next = (gamemode == 2'b01) ? (
        (sw_n == velocity_direction) ? 
            ((velocity + ACCELERATION > MAX_VELOCITY) ? MAX_VELOCITY : velocity + ACCELERATION) :
            ((velocity < ACCELERATION) ? (ACCELERATION - velocity) : velocity - ACCELERATION)
    ) : velocity; // 其他状态保持当前速度

    assign velocity_direction_next = (gamemode == 2'b01) ? (
        (sw_n == velocity_direction) ? velocity_direction :
            ((velocity < ACCELERATION) ? ~velocity_direction : velocity_direction)
    ) : velocity_direction; // 其他状态保持当前方向

    // Player position logic - 只在gamemode 01时更新
    wire [8:0] player_y_calc = velocity_direction_next ? player_y + velocity_next : player_y - velocity_next;

    assign player_y_next = (gamemode == 2'b01) ? (
        (player_y_calc < UPPER_BOUND) ? UPPER_BOUND :
        (player_y_calc > LOWER_BOUND - PLAYER_SIZE) ? (LOWER_BOUND - PLAYER_SIZE) :
        player_y_calc
    ) : player_y; // 其他状态保持当前位置

    // --- Sequential Logic (State Update) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2; // Center the player
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
        end else if (sw[2:1] == 2'b00) begin // 当开关回到初始状态时重置游戏
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2;
            velocity           <= 0;
            crash              <= 2'b00; // 清除crash状态，允许重新开始
            velocity_direction <= 0;
        end else if (crash != 2'b11) begin // 只有在非崩溃状态下才更新游戏逻辑
            player_y           <= player_y_next;
            velocity           <= velocity_next;
            velocity_direction <= velocity_direction_next;

            // Collision detection logic - 只在gamemode 01时进行
            if (gamemode == 2'b01) begin
                crash <= 2'b00; // 假设开始时没有碰撞
                for (integer k = 0; k < 10; k = k + 1) begin
                    logic [9:0] obs_x_left   = obstacle_x[k][19:10];
                    logic [9:0] obs_x_right  = obstacle_x[k][9:0];
                    logic [8:0] obs_y_top    = obstacle_y[k][17:9];
                    logic [8:0] obs_y_bottom = obstacle_y[k][8:0];

                    // AABB collision detection algorithm
                    if ( (PLAYER_X_RIGHT > obs_x_left) &&
                         (PLAYER_X_LEFT < obs_x_right) &&
                         (player_y + PLAYER_SIZE > obs_y_top) &&
                         (player_y < obs_y_bottom) ) 
                    begin
                        crash <= 2'b11; // 设置崩溃状态
                    end
                end
            end
            // 在gamemode 10时不进行crash检测，保持当前crash状态
        end
        // 在crash状态下，保持当前状态不变，直到重置
    end

endmodule