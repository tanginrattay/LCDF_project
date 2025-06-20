// File: map.sv
// Description: 强化随机性的障碍物生成模块 - 增强上下边界概率版本
// 核心改进：
// 1. 使用真随机种子和多级扰动
// 2. 强制Y轴全覆盖算法，特别保证上下边界被覆盖
// 3. 动态调整生成策略防止安全区域
// 4. 新增：增强上下边界生成概率（约40%概率生成在边界区域）

module map(
    input wire rst_n,
    input wire clk, // Input clock (60Hz frame clock)
    input wire [1:0] gamemode,
    output logic [9:0] [9:0] obstacle_x_left,
    output logic [9:0] [9:0] obstacle_x_right,
    output logic [9:0] [8:0] obstacle_y_up,
    output logic [9:0] [8:0] obstacle_y_down
);

//================================================================
// Parameters Definition
//================================================================
localparam NUM_OBSTACLES    = 10;
localparam SCREEN_WIDTH     = 640;
localparam UPPER_BOUND      = 20;
localparam LOWER_BOUND      = 460;
localparam PLAY_AREA_HEIGHT = LOWER_BOUND - UPPER_BOUND;

// Obstacle Parameters
localparam SCROLL_SPEED       = 4;
localparam MIN_OBSTACLE_WIDTH = 20;
localparam MAX_OBSTACLE_WIDTH = 80;
localparam MIN_OBSTACLE_HEIGHT = 20;
localparam MAX_OBSTACLE_HEIGHT = 150;

localparam MIN_GAP_DIFFICULTY = 80;
localparam MAX_GAP_DIFFICULTY = 180;

localparam PLAYER_SIZE_Y      = 40;

// 新增：边界偏好参数
localparam BOUNDARY_PREFERENCE_THRESHOLD = 8'd102;  // 40% 概率选择边界 (102/255 ≈ 40%)
localparam UPPER_BOUNDARY_ZONE_SIZE = 60;           // 上边界区域大小
localparam LOWER_BOUNDARY_ZONE_SIZE = 60;           // 下边界区域大小

//================================================================
// Internal Signal Definitions
//================================================================
reg [NUM_OBSTACLES-1:0] active;
reg [10:0] pos_x [0:NUM_OBSTACLES-1];
reg [8:0]  pos_y [0:NUM_OBSTACLES-1];
reg [6:0]  width [0:NUM_OBSTACLES-1];
reg [7:0]  height [0:NUM_OBSTACLES-1];

reg [10:0] next_spawn_x;
reg [1:0] gamemode_prev;

// Registered outputs
reg [9:0] [9:0] obstacle_x_left_reg;
reg [9:0] [9:0] obstacle_x_right_reg;
reg [9:0] [8:0] obstacle_y_up_reg;
reg [9:0] [8:0] obstacle_y_down_reg;

//================================================================
// 高强度随机数生成系统
//================================================================

// 多个独立的随机数生成器
reg [31:0] rng1, rng2, rng3;
reg [23:0] rng4;
reg [15:0] chaos_counter;      // 混沌计数器
reg [31:0] feedback_shift;     // 反馈移位寄存器
reg [7:0]  noise_accumulator;  // 噪声累积器

// 强制覆盖控制器
reg [4:0] coverage_counter;    // 覆盖计数器 (0-31)
reg [7:0] force_coverage_map;  // 强制覆盖映射表
reg [2:0] last_zone;          // 记录上次生成的区域

// 新增：边界生成统计
reg [7:0] boundary_generation_count;  // 边界生成计数
reg [7:0] total_generation_count;     // 总生成计数

// 初始化和更新所有随机数生成器
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 使用不同的初始种子
        rng1 <= 32'h12345678;
        rng2 <= 32'h9ABCDEF0;
        rng3 <= 32'hFEDCBA98;
        rng4 <= 24'h123456;
        chaos_counter <= 16'h5A5A;
        feedback_shift <= 32'hA5A5A5A5;
        noise_accumulator <= 8'h33;
        coverage_counter <= 5'b0;
        force_coverage_map <= 8'b0;
        last_zone <= 3'b0;
        boundary_generation_count <= 8'b0;
        total_generation_count <= 8'b0;
    end else begin
        // 更新多个LFSR，使用不同的反馈多项式
        rng1 <= {rng1[30:0], rng1[31] ^ rng1[21] ^ rng1[1] ^ rng1[0]};
        rng2 <= {rng2[30:0], rng2[31] ^ rng2[27] ^ rng2[5] ^ rng2[3]};
        rng3 <= {rng3[30:0], rng3[31] ^ rng3[25] ^ rng3[7] ^ rng3[2]};
        rng4 <= {rng4[22:0], rng4[23] ^ rng4[18] ^ rng4[12] ^ rng4[6]};
        
        // 混沌计数器 - 非线性更新
        chaos_counter <= chaos_counter + ((rng1[7:0] & 8'h0F) | 8'h01);
        
        // 反馈移位寄存器 - 基于多个源的反馈
        feedback_shift <= {feedback_shift[30:0], 
                          (rng1[15] ^ rng2[7] ^ rng3[23] ^ rng4[11] ^ chaos_counter[3])};
        
        // 噪声累积器 - 累积所有变化
        noise_accumulator <= noise_accumulator + rng1[7:0] + rng2[15:8] + 
                           rng3[23:16] + rng4[7:0] + chaos_counter[7:0];
        
        // 更新覆盖控制器
        coverage_counter <= coverage_counter + 1;
    end
end

//================================================================
// 超强随机数生成函数
//================================================================

// 生成最终的随机数 - 混合所有源
function automatic [31:0] get_chaos_random;
    input [4:0] counter;
    begin
        // 多层混合，包含时间、位置、历史信息
        get_chaos_random = rng1 ^ rng2 ^ rng3 ^ {rng4, rng4[7:0]} ^ 
                          feedback_shift ^ {noise_accumulator, noise_accumulator, 
                          noise_accumulator, noise_accumulator} ^
                          ({counter, counter, counter, counter, counter, counter, 2'b0} << 
                           (chaos_counter[3:0] % 16)) ^
                          (chaos_counter * 16'hACE1);
    end
endfunction

// 增强上下边界概率的Y轴生成算法
function automatic [8:0] get_enhanced_boundary_y;
    input [31:0] chaos_rng;
    input [7:0] obstacle_height;
    input [4:0] counter;
    input [2:0] last_zone_used;
    input [7:0] coverage_map;
    input [7:0] boundary_count;
    input [7:0] total_count;
    
    reg [8:0] max_y_pos;
    reg [8:0] result_y;
    reg [7:0] boundary_preference;
    reg [7:0] boundary_ratio;
    reg use_boundary_generation;
    reg use_upper_boundary;
    reg [8:0] boundary_offset;
    reg [8:0] middle_area_start, middle_area_end;
    
    begin
        max_y_pos = LOWER_BOUND - obstacle_height;
        
        if (max_y_pos <= UPPER_BOUND) begin
            get_enhanced_boundary_y = UPPER_BOUND;
        end else begin
            // 计算当前边界生成比例
            if (total_count > 0) begin
                boundary_ratio = (boundary_count * 8'd100) / total_count;
            end else begin
                boundary_ratio = 8'd0;
            end
            
            // 动态调整边界偏好 - 如果边界生成不足，增加偏好
            if (boundary_ratio < 8'd35) begin // 如果边界比例小于35%
                boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD + 8'd51; // 增加到60%概率
            end else if (boundary_ratio > 8'd50) begin // 如果边界比例大于50%
                boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD - 8'd25; // 降低到30%概率
            end else begin
                boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD; // 保持40%概率
            end
            
            // 决定是否使用边界生成
            use_boundary_generation = (chaos_rng[7:0] < boundary_preference);
            
            // 强制边界覆盖检查
            if (counter[3:0] == 4'b1111) begin
                if (!coverage_map[0] || !coverage_map[7]) begin
                    use_boundary_generation = 1'b1;
                end
            end
            
            if (use_boundary_generation) begin
                // 边界生成模式
                use_upper_boundary = chaos_rng[8]; // 50%概率选择上边界或下边界
                
                if (use_upper_boundary) begin
                    // 上边界区域生成 (UPPER_BOUND 到 UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE)
                    if (UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE <= max_y_pos) begin
                        boundary_offset = (chaos_rng[23:16] ^ noise_accumulator) % UPPER_BOUNDARY_ZONE_SIZE;
                        result_y = UPPER_BOUND + boundary_offset;
                    end else begin
                        result_y = UPPER_BOUND;
                    end
                end else begin
                    // 下边界区域生成 (max_y_pos - LOWER_BOUNDARY_ZONE_SIZE 到 max_y_pos)
                    if (max_y_pos >= LOWER_BOUNDARY_ZONE_SIZE) begin
                        boundary_offset = (chaos_rng[15:8] ^ noise_accumulator) % LOWER_BOUNDARY_ZONE_SIZE;
                        result_y = max_y_pos - boundary_offset;
                        if (result_y < UPPER_BOUND) result_y = UPPER_BOUND;
                    end else begin
                        result_y = max_y_pos;
                    end
                end
            end else begin
                // 中间区域生成模式 - 避免过度集中在边界
                middle_area_start = UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE;
                middle_area_end = max_y_pos - LOWER_BOUNDARY_ZONE_SIZE;
                
                if (middle_area_end > middle_area_start) begin
                    boundary_offset = (chaos_rng[31:24] ^ chaos_rng[15:8] ^ noise_accumulator) % 
                                    (middle_area_end - middle_area_start);
                    result_y = middle_area_start + boundary_offset;
                end else begin
                    // 如果中间区域太小，使用全范围随机
                    boundary_offset = (chaos_rng[23:16] ^ noise_accumulator) % (max_y_pos - UPPER_BOUND);
                    result_y = UPPER_BOUND + boundary_offset;
                end
            end
            
            // 最终边界检查
            if (result_y > max_y_pos) result_y = max_y_pos;
            if (result_y < UPPER_BOUND) result_y = UPPER_BOUND;
            
            get_enhanced_boundary_y = result_y;
        end
    end
endfunction

// 其他随机生成函数保持不变
function automatic [7:0] get_random_width;
    input [31:0] chaos_rng;
    begin
        get_random_width = MIN_OBSTACLE_WIDTH + 
            ((chaos_rng[7:0] ^ chaos_rng[15:8]) % (MAX_OBSTACLE_WIDTH - MIN_OBSTACLE_WIDTH + 1));
    end
endfunction

function automatic [7:0] get_random_height;
    input [31:0] chaos_rng;
    begin
        get_random_height = MIN_OBSTACLE_HEIGHT + 
            ((chaos_rng[23:16] ^ chaos_rng[31:24]) % (MAX_OBSTACLE_HEIGHT - MIN_OBSTACLE_HEIGHT + 1));
    end
endfunction

function automatic [7:0] get_random_gap;
    input [31:0] chaos_rng;
    begin
        get_random_gap = MIN_GAP_DIFFICULTY + 
            ((chaos_rng[31:24] ^ chaos_rng[7:0]) % (MAX_GAP_DIFFICULTY - MIN_GAP_DIFFICULTY + 1));
    end
endfunction

//================================================================
// 主状态机和障碍物逻辑
//================================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
        gamemode_prev <= 2'b00;
        boundary_generation_count <= 8'b0;
        total_generation_count <= 8'b0;
        for (integer i = 0; i < NUM_OBSTACLES; i++) begin
            active[i] <= 1'b0;
            pos_x[i] <= SCREEN_WIDTH + 100;
            pos_y[i] <= UPPER_BOUND;
            width[i] <= MIN_OBSTACLE_WIDTH;
            height[i] <= MIN_OBSTACLE_HEIGHT;
        end
    end else begin
        gamemode_prev <= gamemode;

        if (gamemode == 2'b00) begin
            // 重置所有状态
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                active[i] <= 1'b0;
                pos_x[i] <= SCREEN_WIDTH + 100;
            end
            next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
            force_coverage_map <= 8'b0;
            boundary_generation_count <= 8'b0;
            total_generation_count <= 8'b0;
        end
        else if (gamemode == 2'b01) begin
            if (gamemode_prev == 2'b00) begin
                for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                    active[i] <= 1'b0;
                    pos_x[i] <= SCREEN_WIDTH + 100;
                end
                next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
                force_coverage_map <= 8'b0;
                boundary_generation_count <= 8'b0;
                total_generation_count <= 8'b0;
            end

            // 移动所有活跃的障碍物
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (active[i]) begin
                    pos_x[i] <= pos_x[i] - SCROLL_SPEED;
                end
            end

            next_spawn_x <= next_spawn_x - SCROLL_SPEED;

            // 删除屏幕外的障碍物
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (active[i] && (pos_x[i] + width[i] < 0)) begin
                    active[i] <= 1'b0;
                end
            end

            // 生成新障碍物
            if (next_spawn_x <= SCREEN_WIDTH) begin
                for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                    if (!active[i]) begin
                        reg [31:0] chaos_random;
                        reg [7:0] new_width, new_height;
                        reg [8:0] new_y_pos;
                        reg [7:0] gap_size;
                        reg [2:0] selected_zone;
                        reg is_boundary_obstacle;

                        // 生成混沌随机数
                        chaos_random = get_chaos_random(coverage_counter);
                        
                        new_width = get_random_width(chaos_random);
                        new_height = get_random_height(chaos_random);
                        
                        // 使用增强的边界生成算法
                        new_y_pos = get_enhanced_boundary_y(chaos_random, new_height, 
                                                          coverage_counter, last_zone, force_coverage_map,
                                                          boundary_generation_count, total_generation_count);
                        gap_size = get_random_gap(chaos_random);

                        // 判断是否为边界障碍物
                        is_boundary_obstacle = (new_y_pos <= (UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE)) ||
                                             (new_y_pos >= (LOWER_BOUND - new_height - LOWER_BOUNDARY_ZONE_SIZE));

                        // 更新统计计数
                        total_generation_count <= total_generation_count + 1;
                        if (is_boundary_obstacle) begin
                            boundary_generation_count <= boundary_generation_count + 1;
                        end
                        
                        // 防止计数器溢出
                        if (total_generation_count == 8'hFF) begin
                            total_generation_count <= 8'd100;
                            boundary_generation_count <= (boundary_generation_count > 8'd100) ? 
                                                        8'd40 : (boundary_generation_count * 8'd100) / 8'hFF;
                        end

                        // 更新覆盖映射
                        selected_zone = ((new_y_pos - UPPER_BOUND) * 8) / (LOWER_BOUND - UPPER_BOUND - new_height);
                        if (selected_zone <= 7) begin
                            force_coverage_map[selected_zone] <= 1'b1;
                        end
                        last_zone <= selected_zone;

                        // 每32个障碍物重置覆盖映射，确保持续覆盖
                        if (coverage_counter == 5'b11111) begin
                            force_coverage_map <= 8'b0;
                        end

                        active[i] <= 1'b1;
                        pos_x[i] <= SCREEN_WIDTH;
                        pos_y[i] <= new_y_pos;
                        width[i] <= new_width[6:0];
                        height[i] <= new_height;

                        next_spawn_x <= SCREEN_WIDTH + gap_size;
                        break;
                    end
                end
            end
        end
    end
end

//================================================================
// 输出逻辑
//================================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer k = 0; k < NUM_OBSTACLES; k++) begin
            obstacle_x_left_reg[k]  <= 10'd700;
            obstacle_x_right_reg[k] <= 10'd700;
            obstacle_y_up_reg[k]    <= 9'd500;
            obstacle_y_down_reg[k]  <= 9'd500;
        end
    end else begin
        for (integer k = 0; k < NUM_OBSTACLES; k++) begin
            if (active[k] && pos_x[k] >= 0 && pos_x[k] < SCREEN_WIDTH) begin
                obstacle_x_left_reg[k]  <= 10'(pos_x[k]);
                obstacle_x_right_reg[k] <= 10'(pos_x[k] + width[k]);
                obstacle_y_up_reg[k]    <= pos_y[k];
                obstacle_y_down_reg[k]  <= 9'(pos_y[k] + height[k]);
            end else begin
                obstacle_x_left_reg[k]  <= 10'd700;
                obstacle_x_right_reg[k] <= 10'd700;
                obstacle_y_up_reg[k]    <= 9'd500;
                obstacle_y_down_reg[k]  <= 9'd500;
            end
        end
    end
end

assign obstacle_x_left  = obstacle_x_left_reg;
assign obstacle_x_right = obstacle_x_right_reg;
assign obstacle_y_up    = obstacle_y_up_reg;
assign obstacle_y_down  = obstacle_y_down_reg;

endmodule