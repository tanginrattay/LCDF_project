module top(
    input wire clk,          
    input wire RST_n,        
    input wire [2:0] sw,
    output wire [3:0] R,     
    output wire [3:0] G,     
    output wire [3:0] B,     
    output wire HS,          
    output wire VS,
    output wire beep,       
    output [1:0] gamemode_led
);

    wire rst_n;
    reg [1:0] clk_div;
    wire clk_25mhz;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_div <= 2'b00;
        else
            clk_div <= clk_div + 1'b1;
    end
    assign clk_25mhz = clk_div[1];  

    wire clk_60hz;
    clkdiv_60hz u_clkdiv_60hz(.clk(clk), .rst_n(rst_n), .clk_60hz(clk_60hz));

    wire [1:0] gamemode;          
    wire [9:0] player_y;          
    wire [2:0] btn_ok;                  
    wire [29:0] obstacle_x;      
    wire [26:0] obstacle_y;      


    // VGA related signals
    wire [9:0] pix_x;      // VGA current pixel X coordinate
    wire [8:0] pix_y;      // VGA current pixel Y coordinate
    wire [11:0] vga_data;  // VGA pixel color data
    wire rdn;              // VGA read enable signal

    Anti_jitter m3(clk, RST_n, rst_n);

    game_logic u_game_logic (
        .rst_n(rst_n),
        .sw(sw),
        .clk(clk_60hz),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .gamemode(gamemode),
        .player_y(player_y)
    );

    map u_map (
        .rst_n(rst_n),
        .clk(clk_60hz),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y)
    );


    // VGA screen image generation module
    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .gamemode(gamemode),
        .player_y(player_y),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .rgb({vga_data[11:8], vga_data[7:4], vga_data[3:0]})  // Convert to 12-bit RGB format
    );

    // VGA controller
    vga_ctrl u_vga_ctrl(
        .clk(clk_25mhz),      // 25MHz VGA clock
        .rst(~rst_n),         // Active-high reset signal
        .Din(vga_data),       // Pixel data input
        .row(pix_y),          // Pixel Y coordinate
        .col(pix_x),          // Pixel X coordinate
        .rdn(rdn),            // Read enable signal
        .R(R),                // Red output
        .G(G),                // Green output
        .B(B),                // Blue output
        .HS(HS),             // Horizontal sync
        .VS(VS)              // Vertical sync
    );

    assign gamemode_led = gamemode;

   top_beep u_top_beep(
       .clk(clk),
       .gamemode(gamemode),
       .beep(beep)
   );

endmodule