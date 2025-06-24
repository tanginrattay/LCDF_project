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
    output wire [2:0] heart,
    // Trail effect outputs
    output reg [40:0] [9:0] trail_x,
    output reg [40:0] [8:0] trail_y,
    output reg [40:0] [3:0] trail_life
);

    wire sw_n = ~sw[0]; // Player control switch
    reg [8:0] velocity;
    reg [1:0] crash; 
    reg velocity_direction; // 0 for up, 1 for down
    
    // Heart system variables
    reg [2:0] heart_reg;
    reg [8:0] safe_time_counter; // Counter for safe time after collision
    wire in_safe_time = (safe_time_counter > 0);
    
    // Game constants
    parameter UPPER_BOUND   = 20;
    parameter LOWER_BOUND   = 460;
    parameter PLAYER_SIZE   = 40;
    parameter PLAYER_X_LEFT = 160;
    parameter PLAYER_X_RIGHT= 200;
    parameter MAX_VELOCITY  = 10;
    parameter ACCELERATION  = 1;
    
    // Heart system constants
    parameter INITIAL_HEARTS = 5;
    parameter SAFE_TIME_DURATION = 60; // 1 seconds at 60Hz
    
    // Trail constants
    parameter TRAIL_COUNT      = 41;
    parameter TRAIL_SPAWN_X    = PLAYER_X_LEFT - 8;
    parameter TRAIL_HORIZONTAL_SPEED = 4;
    parameter TRAIL_MAX_LIFE_CENTER = 10;
    parameter TRAIL_MAX_LIFE_INNER  = 8;
    parameter TRAIL_MAX_LIFE_OUTER  = 6;
    parameter SPAWN_DELAY = 3; // 新增生成粒子的延迟参数
    parameter TAIL_SIZE = 4;   // 新增拖尾大小参数

    // Trail generation variables
    reg [2:0] trail_timer; // Timer for trail generation
    reg [4:0] trail_write_index; // Index for writing new trails
    reg [3:0] spawn_timer; // Timer for controlling particle spawn rate

    // Boundary collision flags
    wire hit_upper_bound = (player_y <= UPPER_BOUND);
    wire hit_lower_bound = (player_y >= LOWER_BOUND - PLAYER_SIZE);
    wire hit_boundary = hit_upper_bound || hit_lower_bound;

    // Heart output assignment
    assign heart = heart_reg;

    // gamemode logic
    always_comb begin
        if (heart_reg == 0) begin
            gamemode = 2'b11; // Game over when no hearts left
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
            heart_reg          <= INITIAL_HEARTS;
            safe_time_counter  <= 0;
            
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
            heart_reg          <= INITIAL_HEARTS;
            safe_time_counter  <= 0;
            
            // Clear all trail points
            for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
                trail_x[i] <= 10'd0;
                trail_y[i] <= 9'd0;
                trail_life[i] <= 4'd0;
            end
            
        end else if (heart_reg > 0) begin // Normal game logic (only when hearts > 0)
            player_y           <= player_y_next;
            velocity           <= velocity_next;
            velocity_direction <= velocity_direction_next;
            
            // Update safe time counter
            if (safe_time_counter > 0) begin
                safe_time_counter <= safe_time_counter - 1;
            end

            // Update existing trail points
            for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
                if (trail_life[i] > 0) begin
                    // Move trail point horizontally (向左移动)
                    trail_x[i] <= trail_x[i] - TRAIL_HORIZONTAL_SPEED;
                    
                    // Apply subtle vertical movement based on ACTUAL velocity and direction
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
                    // Decrease life counter
                    trail_life[i] <= trail_life[i] - 1;
                    
                    // Remove trail points that go off screen or die
                    if (trail_x[i] < 10 || trail_life[i] == 1) begin
                        trail_life[i] <= 4'd0;
                    end
                end
            end

            // --- trail生成逻辑 ---
            if (gamemode == 2'b01) begin
                trail_timer <= trail_timer + 1;
                if (trail_timer >= 2) begin
                    trail_timer <= 0;
                    
                    // 每次生成5个拖尾点
                    // 检查是否有足够的空间生成5个点
                    if (trail_write_index + 5 <= TRAIL_COUNT) begin
                        // 生成5个均匀分布的拖尾点
                        for (integer j = 0; j < 5; j = j + 1) begin
                            trail_x[trail_write_index + j] <= TRAIL_SPAWN_X;
                            // 计算均匀分布的y坐标
                            // 玩家方块高度为PLAYER_SIZE，分成5个等份
                            trail_y[trail_write_index + j] <= player_y + (j * (PLAYER_SIZE / 4)) + TAIL_SIZE;
                            
                            // 根据位置设置不同的生命值
                            if (j == 2) begin // 中心点
                                trail_life[trail_write_index + j] <= TRAIL_MAX_LIFE_CENTER;
                            end else if (j == 1 || j == 3) begin // 内侧点
                                trail_life[trail_write_index + j] <= TRAIL_MAX_LIFE_INNER;
                            end else begin // 外侧点
                                trail_life[trail_write_index + j] <= TRAIL_MAX_LIFE_OUTER;
                            end
                        end
                        
                        // 更新写入索引，每次增加5
                        trail_write_index <= trail_write_index + 5;
                    end else begin
                        // 如果剩余空间不足5个，则重置到开头
                        trail_write_index <= 0;
                        
                        // 生成5个均匀分布的拖尾点
                        for (integer j = 0; j < 5; j = j + 1) begin
                            trail_x[j] <= TRAIL_SPAWN_X;
                            // 计算均匀分布的y坐标
                            trail_y[j] <= player_y + (j * (PLAYER_SIZE / 4)) + TAIL_SIZE;
                            
                            // 根据位置设置不同的生命值
                            if (j == 2) begin // 中心点
                                trail_life[j] <= TRAIL_MAX_LIFE_CENTER;
                            end else if (j == 1 || j == 3) begin // 内侧点
                                trail_life[j] <= TRAIL_MAX_LIFE_INNER;
                            end else begin // 外侧点
                                trail_life[j] <= TRAIL_MAX_LIFE_OUTER;
                            end
                        end
                        
                        trail_write_index <= 5;
                    end
                end
            end

            // Collision detection logic - only in gamemode 01 and when not in safe time
            if (gamemode == 2'b01 && !in_safe_time) begin
                crash <= 2'b00; // Assume no collision initially
                for (integer k = 0; k < 10; k = k + 1) begin
                    // AABB collision detection algorithm
                    if ( (PLAYER_X_RIGHT > obstacle_x_left[k]) &&
                         (PLAYER_X_LEFT < obstacle_x_right[k]) &&
                         (player_y + PLAYER_SIZE > obstacle_y_up[k]) &&
                         (player_y < obstacle_y_down[k]) ) 
                    begin
                        // Collision detected - reduce heart and start safe time
                        if (heart_reg > 1) begin
                            heart_reg <= heart_reg - 1;
                            safe_time_counter <= SAFE_TIME_DURATION;
                        end else begin
                            heart_reg <= 0; // Game over
                        end
                        crash <= 2'b11; // Set crash state for this frame
                    end
                end
            end
            
        end else begin
            // Game over state (heart_reg == 0), still update existing trail points but don't spawn new ones
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


endmodule