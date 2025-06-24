// File: top.sv
// Description: Top-level module with clock domain synchronization fix and trail effect
//              添加双缓冲机制解决VGA显示锯齿问题，并支持拖尾效果

module top(
    input wire clk,         // Main input clock (e.g., 100MHz)
    input wire RST_n,       // On-board reset button (active-low)
    input wire [2:0] sw,    // Switches for game control
    output wire [3:0] R,    // VGA Red output
    output wire [3:0] G,    // VGA Green output
    output wire [3:0] B,    // VGA Blue output
    output wire HS,         // VGA Horizontal Sync
    output wire VS,         // VGA Vertical Sync
//    output wire beep,
    output wire [3:0] AN,
    output wire [7:0] SEGMENT,
    output wire [1:0] gamemode_led,
    output wire [2:0] heart // 添加心脏数量输出
);

    // --- Internal Signals ---
    wire rst_n_debounced; // Debounced active-low reset signal
    wire clk_25mhz;       // 25MHz clock for VGA pixel timing
    wire clk_60hz;        // 60Hz clock for game logic timing
    
    wire score_rst; // Reset signal for score display
    
    wire [13:0] score;
    wire [3:0] bcd3, bcd2, bcd1, bcd0; // BCD outputs for score display

    wire [1:0] gamemode;
    wire [8:0] player_y;
    wire [2:0] heart_game; // 游戏逻辑时钟域的心脏数量
    
    // Trail effect signals from game logic
    wire [40:0] [9:0] trail_x_game;
    wire [40:0] [8:0] trail_y_game;
    wire [40:0] [3:0] trail_life_game;
    
    // 游戏逻辑时钟域的障碍物数据
    logic [9:0] [9:0] obstacle_x_game_left;
    logic [9:0] [9:0] obstacle_x_game_right;
    logic [9:0] [8:0] obstacle_y_game_up;
    logic [9:0] [8:0] obstacle_y_game_down;

    // VGA时钟域的障碍物数据（双缓冲）
    logic [9:0] [9:0] obstacle_x_left_vga;
    logic [9:0] [9:0] obstacle_x_right_vga;
    logic [9:0] [8:0] obstacle_y_up_vga;
    logic [9:0] [8:0] obstacle_y_down_vga;
    logic [8:0] player_y_vga;
    logic [1:0] gamemode_vga;
    logic [2:0] heart_vga; // VGA时钟域的心脏数量（双缓冲）
    
    // VGA时钟域的拖尾数据（双缓冲）
    logic [40:0] [9:0] trail_x_vga;
    logic [40:0] [8:0] trail_y_vga;
    logic [40:0] [3:0] trail_life_vga;
    
    // VGA signals
    wire [9:0] pix_x;
    wire [8:0] pix_y;
    wire [11:0] vga_data_out; // 12-bit color data from screen generator

    // --- Debouncer ---
    assign rst_n_debounced = RST_n;

    // --- Clock Generation ---
    // Generate 25MHz clock for VGA from main clock (assuming 100MHz input)
    reg [1:0] clk_div_25m;
    always_ff @(posedge clk or negedge rst_n_debounced) begin
        if (!rst_n_debounced) clk_div_25m <= 2'b0;
        else clk_div_25m <= clk_div_25m + 1;
    end
    assign clk_25mhz = clk_div_25m[1];

    // Generate 60Hz clock for game logic
    clkdiv_60hz u_clkdiv_60hz(.clk(clk), .rst_n(rst_n_debounced), .clk_60hz(clk_60hz));

    // --- 关键修复：时钟域同步器（增加拖尾数据同步）---
    // 将游戏逻辑数据同步到VGA时钟域，避免锯齿问题
    always_ff @(posedge clk_25mhz or negedge rst_n_debounced) begin
        if (!rst_n_debounced) begin
            // 复位时初始化障碍物数据
            for (integer i = 0; i < 10; i++) begin
                obstacle_x_left_vga[i] <= 10'd700;
                obstacle_x_right_vga[i] <= 10'd700;
                obstacle_y_up_vga[i] <= 9'd500;
                obstacle_y_down_vga[i] <= 9'd500;
            end
            player_y_vga <= 9'd240;
            gamemode_vga <= 2'b00;
            heart_vga <= 3'd5; // 初始化心脏数量
            
            // 复位时初始化拖尾数据
            for (integer i = 0; i < 41; i++) begin
                trail_x_vga[i] <= 10'd0;
                trail_y_vga[i] <= 9'd0;
                trail_life_vga[i] <= 4'd0;
            end
        end else begin
            // 在垂直同步信号（VS）有效时更新显示数据
            // 这样可以确保VGA在绘制下一帧时使用一套完整且稳定的数据
            if (!VS) begin // 在垂直消隐期间更新数据
                // 同步障碍物和玩家数据
                obstacle_x_left_vga <= obstacle_x_game_left;
                obstacle_x_right_vga <= obstacle_x_game_right;
                obstacle_y_up_vga <= obstacle_y_game_up;
                obstacle_y_down_vga <= obstacle_y_game_down;
                player_y_vga <= player_y;
                gamemode_vga <= gamemode;
                heart_vga <= heart_game; // 同步心脏数量
                
                // 同步拖尾数据
                trail_x_vga <= trail_x_game;
                trail_y_vga <= trail_y_game;
                trail_life_vga <= trail_life_game;
            end
            // 否则，保持当前帧的数据不变
        end
    end

    // --- Game Logic Module (Enhanced with Trail Effect and Heart System) ---
    game_logic u_game_logic (
        .rst_n(rst_n_debounced),
        .sw(sw),
        .clk(clk_60hz),                    // 使用60Hz时钟
        .obstacle_x_left(obstacle_x_game_left),
        .obstacle_x_right(obstacle_x_game_right),
        .obstacle_y_up(obstacle_y_game_up),
        .obstacle_y_down(obstacle_y_game_down),
        .gamemode(gamemode),
        .player_y(player_y),
        .heart(heart_game),                // 连接心脏数量输出
        // Trail effect outputs
        .trail_x(trail_x_game),
        .trail_y(trail_y_game),
        .trail_life(trail_life_game)
    );

    // --- Map Generation Module ---
    map u_map (
        .rst_n(rst_n_debounced),
        .clk(clk_60hz),                    // 使用60Hz时钟
        .gamemode(gamemode),
        .score(score),
        .obstacle_x_left(obstacle_x_game_left),
        .obstacle_x_right(obstacle_x_game_right),
        .obstacle_y_up(obstacle_y_game_up),
        .obstacle_y_down(obstacle_y_game_down)
    );

    // --- VGA Screen Picture Generator (Enhanced with Trail Effect) ---
    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode_vga),           // 使用VGA时钟域的同步数据
        .player_y(player_y_vga),           // 使用VGA时钟域的同步数据
        .heart(heart_vga),                 // 传递心脏数量给VGA显示模块
        .obstacle_x_game_left(obstacle_x_left_vga),
        .obstacle_x_game_right(obstacle_x_right_vga),
        .obstacle_y_game_up(obstacle_y_up_vga),
        .obstacle_y_game_down(obstacle_y_down_vga),
        // Trail effect inputs
        .trail_x(trail_x_vga),
        .trail_y(trail_y_vga),
        .trail_life(trail_life_vga),
        .rgb(vga_data_out)
    );

    // --- VGA Controller ---
    vga_ctrl u_vga_ctrl(
        .clk(clk_25mhz),
        .rst(~rst_n_debounced), // vga_ctrl often uses an active-high reset
        .Din(vga_data_out),
        .row(pix_y),
        .col(pix_x),
        .R(R),
        .G(G),
        .B(B),
        .HS(HS),
        .VS(VS)
    );
    
    // --- Other Peripherals ---
    assign gamemode_led = score[1:0];
    assign heart = heart_vga; // 输出心脏数量（使用VGA时钟域同步后的数据）

    assign score_rst = (gamemode == 2'b00); // Reset score when in initial state
    BinToBCD bcd_instance (
        .bin(score),
        .bcd3(bcd3),
        .bcd2(bcd2),
        .bcd1(bcd1),
        .bcd0(bcd0)
    );
    DisplayNumber d1(.clk(clk), .RST(score_rst), .Hexs({bcd3, bcd2, bcd1, bcd0}), 
                    .Points(4'b0000), .LES(4'b0000), .Segment(SEGMENT), .AN(AN));

//    top_beep u_top_beep(
//        .clk(clk),
//        .gamemode(gamemode),
//        .sw(sw[0]),
//        .beep(beep)
//    );

endmodule   