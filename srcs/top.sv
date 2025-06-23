// File: top.sv
// Description: Top-level module with clock domain synchronization fix
//              添加双缓冲机制解决VGA显示锯齿问题

module top(
    input wire clk,         // Main input clock (e.g., 100MHz)
    input wire RST_n,       // On-board reset button (active-low)
    input wire [2:0] sw,    // Switches for game control
    output wire [3:0] R,    // VGA Red output
    output wire [3:0] G,    // VGA Green output
    output wire [3:0] B,    // VGA Blue output
    output wire HS,         // VGA Horizontal Sync
    output wire VS,         // VGA Vertical Sync
    output wire beep,
    output wire [3:0] AN,
    output wire [7:0] SEGMENT,
    output wire [1:0] gamemode_led
);

    // --- Internal Signals ---
    wire rst_n_debounced; // Debounced active-low reset signal
    wire clk_25mhz;       // 25MHz clock for VGA pixel timing
    wire clk_60hz;        // 60Hz clock for game logic timing
    
    wire score_rst; // Reset signal for score display
    
    wire [13:0] score;
    wire [3:0] bcd3, bcd2, bcd1, bcd0; // BCD outputs for score displayB
   

    wire [1:0] gamemode;
    wire [8:0] player_y;
    
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

    // --- 关键修复：时钟域同步器 ---
    // 将游戏逻辑数据同步到VGA时钟域，避免锯齿问题
    always_ff @(posedge clk_25mhz or negedge rst_n_debounced) begin
    if (!rst_n_debounced) begin
        // 复位时初始化
        for (integer i = 0; i < 10; i++) begin
            obstacle_x_left_vga[i] <= 10'd700;
            obstacle_x_right_vga[i] <= 10'd700;
            obstacle_y_up_vga[i] <= 9'd500;
            obstacle_y_down_vga[i] <= 9'd500;
        end
        player_y_vga <= 9'd240;
        gamemode_vga <= 2'b00;
    end else begin
        // 在垂直同步信号（VS）有效时（通常是VS的上升沿或在VBI期间）更新显示数据
        // 这样可以确保VGA在绘制下一帧时使用一套完整且稳定的数据
        if (!VS) begin // 或者在VS的某个特定相位
            obstacle_x_left_vga <= obstacle_x_game_left;
            obstacle_x_right_vga <= obstacle_x_game_right;
            obstacle_y_up_vga <= obstacle_y_game_up;
            obstacle_y_down_vga <= obstacle_y_game_down;
            player_y_vga <= player_y;
            gamemode_vga <= gamemode;
        end
        // 否则，保持当前帧的数据不变
    end
end

    // --- Game Logic Module ---
    game_logic u_game_logic (
        .rst_n(rst_n_debounced),
        .sw(sw),
        .clk(clk_60hz),                    // 使用60Hz时钟
        .obstacle_x_left(obstacle_x_game_left),
        .obstacle_x_right(obstacle_x_game_right),
        .obstacle_y_up(obstacle_y_game_up),
        .obstacle_y_down(obstacle_y_game_down),
        .gamemode(gamemode),
        .player_y(player_y)
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

    // --- VGA Screen Picture Generator ---
    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode_vga),           // 使用VGA时钟域的同步数据
        .player_y(player_y_vga),           // 使用VGA时钟域的同步数据
        .obstacle_x_game_left(obstacle_x_left_vga),
        .obstacle_x_game_right(obstacle_x_right_vga),
        .obstacle_y_game_up(obstacle_y_up_vga),
        .obstacle_y_game_down(obstacle_y_down_vga),
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

    top_beep u_top_beep(
        .clk(clk),
        .gamemode(gamemode),
        .sw(sw[0]),
        .beep(beep)
    );

endmodule