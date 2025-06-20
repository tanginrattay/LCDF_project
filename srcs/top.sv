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
//  output wire beep,
    output wire [1:0] gamemode_led
);

    // --- Internal Signals ---
    wire rst_n_debounced; // Debounced active-low reset signal
    wire clk_25mhz;       // 25MHz clock for VGA pixel timing
    wire clk_60hz;        // 60Hz clock for game logic timing
    
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
            for (integer i = 0; i < 10; i++) begin
                obstacle_x_left_vga[i] <= 10'd700;
                obstacle_x_right_vga[i] <= 10'd700;
                obstacle_y_up_vga[i] <= 9'd500;
                obstacle_y_down_vga[i] <= 9'd500;
            end
            player_y_vga <= 9'd240;
            gamemode_vga <= 2'b00;
        end else begin
            // Synchronize all display data to VGA clock domain
            obstacle_x_left_vga <= obstacle_x_game_left;
            obstacle_x_right_vga <= obstacle_x_game_right;
            obstacle_y_up_vga <= obstacle_y_game_up;
            obstacle_y_down_vga <= obstacle_y_game_down;
            player_y_vga <= player_y;
            gamemode_vga <= gamemode;
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
        .obstacle_x_left(obstacle_x_game_left),
        .obstacle_x_right(obstacle_x_game_right),
        .obstacle_y_up(obstacle_y_game_up),
        .obstacle_y_down(obstacle_y_game_down)
    );

    // --- VGA Screen Picture Generator ---
    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk)
        .gamemode(gamemode_vga),           // 使用VGA时钟域的同步数据
        .player_y(player_y_vga),           // 使用VGA时钟域的同步数据
        .obstacle_x_left(obstacle_x_left_vga),
        .obstacle_x_right(obstacle_x_right_vga),
        .obstacle_y_up(obstacle_y_up_vga),
        .obstacle_y_down(obstacle_y_down_vga),
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
    assign gamemode_led = gamemode;

endmodule

//================================================================
// 改进的时钟分频器 - 更精确的60Hz生成
//================================================================
module clkdiv_60hz_improved(
    input wire clk,        // 100MHz input clock
    input wire rst_n,      // Active-low reset signal
    output reg clk_60hz    // Exactly 60Hz output clock
);
    // 更精确的计算：100MHz / 60Hz = 1,666,667 cycles
    // 使用除法器生成更准确的60Hz
    parameter COUNTER_MAX = 1666667 - 1;
    
    reg [20:0] counter;  // 21位计数器足够容纳1,666,667
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 21'd0;
            clk_60hz <= 1'b0;
        end else begin
            if (counter == COUNTER_MAX) begin
                counter <= 21'd0;
                clk_60hz <= ~clk_60hz;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule