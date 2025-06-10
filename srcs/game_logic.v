module game_logic(
    input wire rst_n,
    input wire clk,
    input wire [2:0] btn,         // btn[0]: 切换方向, btn[1]: 开始/暂停, btn[2]: 结束/重置
    input wire [199:0] obstacle_x, // 障碍物 x 坐标 (10个障碍物, 每个20位)
    input wire [179:0] obstacle_y, // 障碍物 y 坐标 (10个障碍物, 每个18位)
    output reg [1:0] gamemode,     // 游戏模式: 00=初始, 01=游戏中, 10=暂停, 11=结束
    output reg [8:0] player_y      // 玩家 y 坐标
);

    parameter UPER_BOUND = 120;
    parameter LOWER_BOUND = 360;
    parameter PLAYER_SIZE = 40;
    parameter ACCELERATION = 1;  
    parameter MAX_VELOCITY = 8;
    parameter PLAYER_X = 160;

    reg signed [9:0] velocity;    // 当前速度 (有符号数，支持正负方向)
    reg direction;                 // 0: 向下, 1: 向上
    reg collision;                 // 0: 未碰撞, 1: 碰撞
    reg [9:0] collision_flags;     // 每障碍物的碰撞标志
    reg btn0_prev;                 // 用于 btn[0] 边沿检测
    reg btn1_prev;                 // 用于 btn[1] 边沿检测
    reg btn2_prev;                 // 用于 btn[2] 边沿检测

    integer k;

    reg [9:0] next_collision_flags;
    reg [9:0] obs_x_left; 
    reg [9:0] obs_x_right;     
    reg [8:0] obs_y_top;       
    reg [8:0] obs_y_bottom;

    reg btn1_posedge;
    reg btn2_posedge;

    always @(posedge clk or negedge rst_n) begin
        
        if (!rst_n) begin
            collision <= 1'b0;
            collision_flags <= 10'b0;
        end else begin
            next_collision_flags = 10'b0;

            for (k = 0; k < 10; k = k + 1) begin
                obs_x_left   = obstacle_x[k*20 +: 10];
                obs_x_right  = obstacle_x[k*20+10 +: 10];
                obs_y_top    = obstacle_y[k*18 +: 9];
                obs_y_bottom = obstacle_y[k*18+9 +: 9];

                // 检查障碍物是否有效
                if (!(obs_x_left == obs_x_right && obs_y_top == obs_y_bottom)) begin
                    // 检查 x 和 y 方向是否重叠
                    if (PLAYER_X < obs_x_right && PLAYER_X + PLAYER_SIZE > obs_x_left &&
                        player_y < obs_y_bottom && player_y + PLAYER_SIZE > obs_y_top) begin
                        next_collision_flags[k] = 1'b1;
                    end
                end
            end
            
            // 在所有计算完成后，用一次非阻塞赋值'<='更新最终的状态寄存器
            collision_flags <= next_collision_flags;
            collision <= |next_collision_flags; // 或归约
        end
    end

    // 主游戏逻辑
// --- 修正后的主游戏逻辑 ---

// 为下一个状态创建临时寄存器
reg [8:0] next_player_y;
reg signed [9:0] next_velocity;
reg next_direction;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gamemode <= 2'b00;
        player_y <= (LOWER_BOUND + UPER_BOUND) / 2;
        velocity <= 0;
        direction <= 0;
        btn0_prev <= 1'b0;
        btn1_prev <= 1'b0;
        btn2_prev <= 1'b0;
    end else begin
        // 更新按键历史值
        btn0_prev <= btn[0];
        btn1_prev <= btn[1];
        btn2_prev <= btn[2];
        
        // 状态机部分保持不变
        btn1_posedge <= btn[1] && !btn1_prev;
        btn2_posedge <= btn[2] && !btn2_prev;

        case (gamemode)
            2'b00: begin // 初始化状态
                if (btn1_posedge) begin
                    gamemode <= 2'b01;
                    // 重置游戏状态
                    player_y <= (LOWER_BOUND + UPER_BOUND) / 2;
                    velocity <= 0;
                    direction <= 0;
                end
            end
            2'b01: begin // 游戏进行中
                if (btn1_posedge) begin
                    gamemode <= 2'b10; // 暂停
                end else if (btn2_posedge || collision) begin
                    gamemode <= 2'b11; // 结束游戏
                end else begin
                    // 在这里，我们将所有物理计算的结果先存入 next_ 变量
                    // 然后在 always 块的末尾统一赋值给 player_y, velocity 等
                    // 这种写法可以避免时序逻辑中的竞争和多重驱动问题
                end
            end
            2'b10: begin // 暂停
                if (btn1_posedge) gamemode <= 2'b01; // 恢复游戏
                if (btn2_posedge) gamemode <= 2'b11; // 结束游戏
            end
            2'b11: begin // 结束
                if (btn2_posedge) gamemode <= 2'b00; // 重置到初始状态
            end
            default: gamemode <= 2'b00;
        endcase
        
        // 仅在游戏进行中 (gamemode == 2'b01) 才更新物理状态
        if (gamemode == 2'b01) begin
            player_y <= next_player_y;
            velocity <= next_velocity;
            direction <= next_direction;
        end
    end
end

// --- 新增的组合逻辑块，用于计算下一个状态 ---
// 这个 always 块对所有输入敏感，是纯组合逻辑
always @(*) begin
    next_player_y = player_y;
    next_velocity = velocity;
    next_direction = direction;

    // Handle direction switch first
    if (btn[0] && !btn0_prev) begin
        next_direction = ~direction;
        next_velocity = 0; // Reset velocity on direction switch
    end

    // Update velocity based on current direction, only if not switching
    if (next_direction) begin // Upward
        if (next_velocity < MAX_VELOCITY) begin
            next_velocity = next_velocity + ACCELERATION;
        end
    end else begin // Downward
        if (next_velocity > -MAX_VELOCITY) begin
            next_velocity = next_velocity - ACCELERATION;
        end
    end

    // Update position
    next_player_y = player_y - next_velocity;

    // Boundary checks
    if (next_player_y < UPER_BOUND) begin
        next_player_y = UPER_BOUND;
        next_velocity = 0;
    end
    if (next_player_y > LOWER_BOUND - PLAYER_SIZE) begin
        next_player_y = LOWER_BOUND - PLAYER_SIZE;
        next_velocity = 0;
    end
end

endmodule