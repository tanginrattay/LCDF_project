// File: map.sv
// Description: 完全重新设计的障碍物生成模块
// 解决Y坐标生成问题，确保障碍物在整个游戏区域内随机分布

module map(
    input wire rst_n,
    input wire clk, // Input clock (60Hz frame clock)
    output logic [9:0] [19:0] obstacle_x,
    output logic [9:0] [17:0] obstacle_y
);

//================================================================
// 参数定义
//================================================================
localparam NUM_OBSTACLES = 10;
localparam SCREEN_WIDTH = 640;
localparam UPPER_BOUND = 20;
localparam LOWER_BOUND = 440;
localparam PLAY_AREA_HEIGHT = LOWER_BOUND - UPPER_BOUND; // 420

// 障碍物参数
localparam SCROLL_SPEED = 2;
localparam MIN_OBSTACLE_WIDTH = 20;
localparam MAX_OBSTACLE_WIDTH = 80;
localparam MIN_OBSTACLE_HEIGHT = 20;
localparam MAX_OBSTACLE_HEIGHT = 150;
localparam MIN_GAP = 120;
localparam MAX_GAP = 250;

//================================================================
// 内部信号定义
//================================================================
// 障碍物状态寄存器
reg [NUM_OBSTACLES-1:0] active;
reg [10:0] pos_x [0:NUM_OBSTACLES-1];  // 支持负数用于越界检测
reg [8:0]  pos_y [0:NUM_OBSTACLES-1];
reg [6:0]  width [0:NUM_OBSTACLES-1];  // 减少位宽，足够存储20-80
reg [7:0]  height [0:NUM_OBSTACLES-1];

// 生成控制
reg [10:0] next_spawn_x;
reg [31:0] rng_state;
reg [3:0] spawn_counter; // 防止同一帧生成多个障碍物

//================================================================
// 随机数生成器 (32位LFSR)
//================================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rng_state <= 32'h12345678; // 避免全0状态
    end else begin
        // 32位LFSR: x^32 + x^22 + x^2 + x^1 + 1
        rng_state <= {rng_state[30:0], rng_state[31] ^ rng_state[21] ^ rng_state[1] ^ rng_state[0]};
    end
end

//================================================================
// 随机数提取函数
//================================================================
function automatic [7:0] get_random_width;
    input [31:0] rng;
    begin
        get_random_width = MIN_OBSTACLE_WIDTH + (rng[7:0] % (MAX_OBSTACLE_WIDTH - MIN_OBSTACLE_WIDTH + 1));
    end
endfunction

function automatic [7:0] get_random_height;
    input [31:0] rng;
    begin
        get_random_height = MIN_OBSTACLE_HEIGHT + (rng[15:8] % (MAX_OBSTACLE_HEIGHT - MIN_OBSTACLE_HEIGHT + 1));
    end
endfunction

function automatic [8:0] get_random_y_position;
    input [31:0] rng;
    input [7:0] obstacle_height;
    reg [8:0] max_y_pos;
    begin
        // 确保障碍物完全在游戏区域内
        max_y_pos = LOWER_BOUND - obstacle_height;
        if (max_y_pos <= UPPER_BOUND) begin
            get_random_y_position = UPPER_BOUND;
        end else begin
            // 在UPPER_BOUND到max_y_pos之间随机选择
            get_random_y_position = UPPER_BOUND + (rng[31:24] % (max_y_pos - UPPER_BOUND + 1));
        end
    end
endfunction

function automatic [7:0] get_random_gap;
    input [31:0] rng;
    begin
        get_random_gap = MIN_GAP + (rng[23:16] % (MAX_GAP - MIN_GAP + 1));
    end
endfunction

//================================================================
// 主状态机
//================================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 重置所有状态
        next_spawn_x <= SCREEN_WIDTH + MIN_GAP;
        spawn_counter <= 0;
        
        for (integer i = 0; i < NUM_OBSTACLES; i++) begin
            active[i] <= 1'b0;
            pos_x[i] <= SCREEN_WIDTH + 100; // 初始位置在屏幕外
            pos_y[i] <= UPPER_BOUND;
            width[i] <= MIN_OBSTACLE_WIDTH;
            height[i] <= MIN_OBSTACLE_HEIGHT;
        end
        
    end else begin
        
        // 更新生成计数器（用于时序控制）
        spawn_counter <= spawn_counter + 1;
        
        //------------------------------------------------------------
        // 1. 移动所有活跃的障碍物
        //------------------------------------------------------------
        for (integer i = 0; i < NUM_OBSTACLES; i++) begin
            if (active[i]) begin
                pos_x[i] <= pos_x[i] - SCROLL_SPEED;
            end
        end
        
        // 移动下次生成位置
        next_spawn_x <= next_spawn_x - SCROLL_SPEED;
        
        //------------------------------------------------------------
        // 2. 回收超出屏幕的障碍物
        //------------------------------------------------------------
        for (integer i = 0; i < NUM_OBSTACLES; i++) begin
            if (active[i] && (pos_x[i] + width[i] < 0)) begin
                active[i] <= 1'b0;
            end
        end
        
        //------------------------------------------------------------
        // 3. 生成新障碍物
        //------------------------------------------------------------
        if (next_spawn_x <= SCREEN_WIDTH && spawn_counter[1:0] == 2'b00) begin
            // 寻找空闲槽位
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (!active[i]) begin
                    // 生成新障碍物
                    reg [7:0] new_width, new_height;
                    reg [8:0] new_y_pos;
                    reg [7:0] gap_size;
                    
                    // 计算新障碍物参数
                    new_width = get_random_width(rng_state);
                    new_height = get_random_height(rng_state);
                    new_y_pos = get_random_y_position(rng_state, new_height);
                    gap_size = get_random_gap(rng_state);
                    
                    // 设置障碍物
                    active[i] <= 1'b1;
                    pos_x[i] <= SCREEN_WIDTH;
                    pos_y[i] <= new_y_pos;
                    width[i] <= new_width[6:0];
                    height[i] <= new_height;
                    
                    // 设置下次生成位置
                    next_spawn_x <= SCREEN_WIDTH + gap_size;
                    
                    // 只生成一个后退出循环
                    break;
                end
            end
        end
    end
end

//================================================================
// 输出逻辑
//================================================================
always_comb begin
    for (integer k = 0; k < NUM_OBSTACLES; k++) begin
        if (active[k] && pos_x[k] >= 0 && pos_x[k] < SCREEN_WIDTH) begin
            // 活跃且在屏幕内的障碍物
            obstacle_x[k] = {10'(pos_x[k]), 10'(pos_x[k] + width[k])};
            obstacle_y[k] = {pos_y[k], 9'(pos_y[k] + height[k])};
        end else begin
            // 非活跃或超出屏幕的障碍物，放置在屏幕外
            obstacle_x[k] = {10'd700, 10'd700};
            obstacle_y[k] = {9'd500, 9'd500};
        end
    end
end


endmodule