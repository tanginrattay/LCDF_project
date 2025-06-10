module game_logic(
    input wire rst_n,
    input wire clk,
    input [2:0] sw,
    input wire [199:0] obstacle_x, // Obstacle x coordinates (10 obstacles, 20 bits each)
    input wire [179:0] obstacle_y, // Obstacle y coordinates (10 obstacles, 18 bits each)
    output wire [1:0] gamemode,    // Game mode: 00=initial, 01=in-game, 10=paused, 11=ended
    output reg [8:0] player_y      // Player y coordinate
);

    reg [8:0] velocity;           // Player velocity for movement
    reg [1:0] crash;              // 00: no crash; 11: crash happened
    reg velocity_direction;       // 0: up; 1: down 

    parameter UPER_BOUND    = 40;
    parameter LOWER_BOUND   = 480;
    parameter PLAYER_SIZE   = 40;
    parameter MAX_VELOCITY  = 8;
    parameter ACCELERATION  = 1;

    assign gamemode = sw[2:1] | crash; // Game mode logic

    // 组合逻辑部分
    wire [8:0] velocity_next;
    wire velocity_direction_next;
    wire [8:0] player_y_next;

    // 速度和方向组合逻辑
    assign velocity_next = (gamemode == 2'b01) ? (
        (sw[0] == velocity_direction) ? 
            ((velocity + ACCELERATION > MAX_VELOCITY) ? MAX_VELOCITY : velocity + ACCELERATION) :
            ((velocity < ACCELERATION) ? (ACCELERATION - velocity) : velocity - ACCELERATION)
    ) : 9'd0;

    assign velocity_direction_next = (gamemode == 2'b01) ? (
        (sw[0] == velocity_direction) ? velocity_direction :
            ((velocity < ACCELERATION) ? ~velocity_direction : velocity_direction)
    ) : 1'b0;

    // 位置组合逻辑
    wire [8:0] player_y_calc = velocity_direction_next ? player_y + velocity_next : player_y - velocity_next;
    assign player_y_next = (gamemode == 2'b01) ? (
        (player_y_calc < UPER_BOUND) ? UPER_BOUND :
        (player_y_calc > LOWER_BOUND - PLAYER_SIZE) ? (LOWER_BOUND - PLAYER_SIZE) :
        player_y_calc
    ) : player_y;

    // 时序逻辑部分
    always @(posedge clk) begin
        if (gamemode == 2'b00) begin
            player_y           <= (LOWER_BOUND - UPER_BOUND) / 2;
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
        end else begin
            player_y           <= player_y_next;
            velocity           <= velocity_next;
            velocity_direction <= velocity_direction_next;
            // crash 可根据你的游戏逻辑补充
        end
    end

endmodule