// File: game_logic.sv
// Enhanced with trail effect for player - Fixed boundary velocity reset

module game_logic(
    input wire rst_n,
    input wire clk, // 60Hz frame clock
    input [2:0] sw,
    input logic [9:0] [9:0] obstacle_x_left,
    input logic [9:0] [9:0] obstacle_x_right,
    input logic [9:0] [8:0] obstacle_y_up,
    input logic [9:0] [8:0] obstacle_y_down,
    output reg [1:0] gamemode,
    output reg [8:0] player_y,
    // Trail effect outputs
    output reg [40:0] [9:0] trail_x,
    output reg [40:0] [8:0] trail_y,
    output reg [40:0] [3:0] trail_life
);

    wire sw_n = ~sw[0]; // Player control switch
    reg [8:0] velocity;
    reg [1:0] crash; 
    reg velocity_direction; // 0 for up, 1 for down
    
    // Game constants
    parameter UPPER_BOUND   = 20;
    parameter LOWER_BOUND   = 460;
    parameter PLAYER_SIZE   = 40;
    parameter PLAYER_X_LEFT = 160;
    parameter PLAYER_X_RIGHT= 200;
    parameter MAX_VELOCITY  = 10;
    parameter ACCELERATION  = 1;
    
    // Trail constants
    parameter TRAIL_COUNT      = 41;
    parameter TRAIL_SPAWN_X    = PLAYER_X_LEFT - 8;
    parameter TRAIL_HORIZONTAL_SPEED = 4;
    parameter TRAIL_MAX_LIFE_CENTER = 10;
    parameter TRAIL_MAX_LIFE_INNER  = 8;
    parameter TRAIL_MAX_LIFE_OUTER  = 6;
    parameter SPAWN_DELAY = 3; // 新增生成粒子的延迟参数

    // Trail generation variables
    reg [2:0] trail_timer; // Timer for trail generation
    reg [4:0] trail_write_index; // Index for writing new trails
    reg [3:0] spawn_timer; // Timer for controlling particle spawn rate

    // Boundary collision flags
    wire hit_upper_bound = (player_y <= UPPER_BOUND);
    wire hit_lower_bound = (player_y >= LOWER_BOUND - PLAYER_SIZE);
    wire hit_boundary = hit_upper_bound || hit_lower_bound;

    // gamemode logic
    always_comb begin
        if (crash == 2'b11) begin
            gamemode = 2'b11;
        end else begin
            gamemode = sw[2:1];
        end
    end

    // Enhanced velocity and direction logic with boundary handling
    wire [8:0] velocity_next = (gamemode == 2'b01) ? (
        // If hitting boundary and trying to move into it, set velocity to 0
        (hit_upper_bound && velocity_direction == 0) ? 9'd0 :
        (hit_lower_bound && velocity_direction == 1) ? 9'd0 :
        // Normal velocity calculation
        (sw_n == velocity_direction) ? 
            ((velocity + ACCELERATION > MAX_VELOCITY) ? MAX_VELOCITY : velocity + ACCELERATION) :
            ((velocity < ACCELERATION) ? (ACCELERATION - velocity) : velocity - ACCELERATION)
    ) : velocity;

    wire velocity_direction_next = (gamemode == 2'b01) ? (
        // If hitting boundary, don't change direction unless switching control
        (hit_boundary && sw_n != velocity_direction) ? ~velocity_direction :
        // Normal direction logic
        (sw_n == velocity_direction) ? velocity_direction :
            ((velocity < ACCELERATION) ? ~velocity_direction : velocity_direction)
    ) : velocity_direction;

    // Player position logic - simplified since velocity is now properly controlled
    wire [8:0] player_y_calc = velocity_direction_next ? player_y + velocity_next : player_y - velocity_next;
    wire [8:0] player_y_next = (gamemode == 2'b01) ? (
        (player_y_calc < UPPER_BOUND) ? UPPER_BOUND :
        (player_y_calc > LOWER_BOUND - PLAYER_SIZE) ? (LOWER_BOUND - PLAYER_SIZE) :
        player_y_calc
    ) : player_y;

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2;
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
            trail_timer        <= 0;
            trail_write_index  <= 0;
            spawn_timer        <= 0;
            
            // Initialize trail points
            for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
                trail_x[i] <= 10'd0;
                trail_y[i] <= 9'd0;
                trail_life[i] <= 4'd0;
            end
            
        end else if (sw[2:1] == 2'b00) begin // Reset game
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2;
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
            trail_timer        <= 0;
            trail_write_index  <= 0;
            spawn_timer        <= 0;
            
            // Clear all trail points
            for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
                trail_x[i] <= 10'd0;
                trail_y[i] <= 9'd0;
                trail_life[i] <= 4'd0;
            end
            
        end else if (crash != 2'b11) begin // Normal game logic
            player_y           <= player_y_next;
            velocity           <= velocity_next;
            velocity_direction <= velocity_direction_next;

            // Update existing trail points
            for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
                if (trail_life[i] > 0) begin
                    // Move trail point horizontally (向左移动)
                    trail_x[i] <= trail_x[i] - TRAIL_HORIZONTAL_SPEED;
                    
                    // Apply subtle vertical movement based on ACTUAL velocity and direction
                    // Only apply vertical movement if velocity is significant and not at boundary
                    if (gamemode == 2'b01 && velocity > 1 && !hit_boundary) begin
                        if (velocity_direction == 0) begin
                            // Player moving up, trail moves down slightly
                            trail_y[i] <= trail_y[i] + (velocity >> 2);
                        end else begin
                            // Player moving down, trail moves up slightly
                            if (trail_y[i] >= (velocity >> 2)) begin
                                trail_y[i] <= trail_y[i] - (velocity >> 2);
                            end else begin
                                trail_y[i] <= 0;
                            end
                        end
                    end
                    // If at boundary or low velocity, trail moves purely horizontally
                    
                    // Decrease life counter
                    trail_life[i] <= trail_life[i] - 1;
                    
                    // Remove trail points that go off screen or die
                    if (trail_x[i] < 10 || trail_life[i] == 1) begin
                        trail_life[i] <= 4'd0;
                    end
                end
            end
            
            // Enhanced trail spawning - adjust based on velocity and boundary status
            if (gamemode == 2'b01) begin
                trail_timer <= trail_timer + 1;
                
                // Every 2 cycles, try to spawn a new trail point
                if (trail_timer >= 2) begin
                    trail_timer <= 0;
                    
                    // Find next available index (循环使用)
                    trail_write_index <= (trail_write_index >= TRAIL_COUNT - 1) ? 0 : (trail_write_index + 1);
                    
                    // Always spawn at the current write index (overwrite if necessary)
                    trail_x[trail_write_index] <= TRAIL_SPAWN_X;
                    trail_y[trail_write_index] <= player_y + PLAYER_SIZE/2; // Start with center point
                    trail_life[trail_write_index] <= TRAIL_MAX_LIFE_CENTER;
                    
                    // Spawn offset points with adjusted positioning based on velocity
                    if (trail_write_index + 1 < TRAIL_COUNT && trail_life[trail_write_index + 1] == 0) begin
                        trail_x[trail_write_index + 1] <= TRAIL_SPAWN_X;
                        // Adjust vertical offset based on movement direction and velocity
                        if (velocity > 3 && !hit_boundary) begin
                            trail_y[trail_write_index + 1] <= velocity_direction ? 
                                (player_y + PLAYER_SIZE/2 - (velocity >> 1)) : 
                                (player_y + PLAYER_SIZE/2 + (velocity >> 1));
                        end else begin
                            trail_y[trail_write_index + 1] <= player_y + PLAYER_SIZE/2 - 8;
                        end
                        trail_life[trail_write_index + 1] <= TRAIL_MAX_LIFE_INNER;
                    end
                    
                    if (trail_write_index + 2 < TRAIL_COUNT && trail_life[trail_write_index + 2] == 0) begin
                        trail_x[trail_write_index + 2] <= TRAIL_SPAWN_X;
                        // Adjust vertical offset based on movement direction and velocity
                        if (velocity > 3 && !hit_boundary) begin
                            trail_y[trail_write_index + 2] <= velocity_direction ? 
                                (player_y + PLAYER_SIZE/2 + (velocity >> 1)) : 
                                (player_y + PLAYER_SIZE/2 - (velocity >> 1));
                        end else begin
                            trail_y[trail_write_index + 2] <= player_y + PLAYER_SIZE/2 + 8;
                        end
                        trail_life[trail_write_index + 2] <= TRAIL_MAX_LIFE_INNER;
                    end
                end
            end

            // Collision detection logic - only in gamemode 01
            if (gamemode == 2'b01) begin
                crash <= 2'b00; // Assume no collision initially
                for (integer k = 0; k < 10; k = k + 1) begin
                    // AABB collision detection algorithm
                    if ( (PLAYER_X_RIGHT > obstacle_x_left[k]) &&
                         (PLAYER_X_LEFT < obstacle_x_right[k]) &&
                         (player_y + PLAYER_SIZE > obstacle_y_up[k]) &&
                         (player_y < obstacle_y_down[k]) ) 
                    begin
                        crash <= 2'b11; // Set crash state
                    end
                end
            end
            
        end else begin
            // In crash state, still update existing trail points but don't spawn new ones
            for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
                if (trail_life[i] > 0) begin
                    // Continue moving existing trail points
                    trail_x[i] <= trail_x[i] - TRAIL_HORIZONTAL_SPEED;
                    trail_life[i] <= trail_life[i] - 1;
                    
                    // Remove trail points that go off screen or die
                    if (trail_x[i] < 10 || trail_life[i] == 1) begin
                        trail_life[i] <= 4'd0;
                    end
                end
            end
        end
    end

    // 新增粒子生成逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位逻辑
        end else if (gamemode == 2'b01) begin // 游戏进行中
            // 更新所有已存在粒子的位置和生命值
            
            // 每帧固定生成5个新粒子
            if (spawn_timer == 0) begin  // 可以控制生成频率
                // 计算当前写入索引，每次增加5
                trail_write_index <= (trail_write_index >= TRAIL_COUNT - 5) ? 0 : trail_write_index + 5;
                
                // 最上点 (玩家上边界)
                trail_x[trail_write_index] <= TRAIL_SPAWN_X;
                trail_y[trail_write_index] <= player_y;
                trail_life[trail_write_index] <= TRAIL_MAX_LIFE_OUTER;
                
                // 上点 (中心上方)
                trail_x[trail_write_index+1] <= TRAIL_SPAWN_X;
                trail_y[trail_write_index+1] <= player_y + PLAYER_SIZE/4;
                trail_life[trail_write_index+1] <= TRAIL_MAX_LIFE_INNER;
                
                // 中心点
                trail_x[trail_write_index+2] <= TRAIL_SPAWN_X;
                trail_y[trail_write_index+2] <= player_y + PLAYER_SIZE/2;
                trail_life[trail_write_index+2] <= TRAIL_MAX_LIFE_CENTER;
                
                // 下点 (中心下方)
                trail_x[trail_write_index+3] <= TRAIL_SPAWN_X;
                trail_y[trail_write_index+3] <= player_y + PLAYER_SIZE*3/4;
                trail_life[trail_write_index+3] <= TRAIL_MAX_LIFE_INNER;
                
                // 最下点 (玩家下边界)
                trail_x[trail_write_index+4] <= TRAIL_SPAWN_X;
                trail_y[trail_write_index+4] <= player_y + PLAYER_SIZE;
                trail_life[trail_write_index+4] <= TRAIL_MAX_LIFE_OUTER;
                
                spawn_timer <= SPAWN_DELAY; // 设置生成间隔
            end else begin
                spawn_timer <= spawn_timer - 1;
            end
        end
    end

endmodule