module top(
    input wire clk,          
    input wire RST_n,        
    input wire ps2_clk,
    input wire ps2_data,
    output wire [3:0] R,     
    output wire [3:0] G,     
    output wire [3:0] B,     
    output wire HS,          
    output wire VS,
    output wire [1:0] gamemode_led     
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
    wire [199:0] obstacle_x;      
    wire [179:0] obstacle_y;      
 

    wire [9:0] pix_x;     
    wire [8:0] pix_y;     
    wire [11:0] vga_data;     
    wire rdn;             

    Anti_jitter m3(clk, RST_n, rst_n);

    game_logic u_game_logic (
        .rst_n(rst_n),
        .dir(dir),
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


    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .gamemode(gamemode),
        .player_y(player_y),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .rgb({vga_data[11:8], vga_data[7:4], vga_data[3:0]})  
    );


    vga_ctrl u_vga_ctrl(
        .clk(clk_25mhz),    
        .rst(~rst_n),       
        .Din(vga_data),     
        .row(pix_y),        
        .col(pix_x),        
        .rdn(rdn),          
        .R(R),              
        .G(G),              
        .B(B),              
        .HS(HS),             
        .VS(VS)              
    );

    ps2_dlc u_ps2_dlc(
        .clk(clk),
        .rst(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .dir(dir)  // 0: up, 1: down, 2: left, 3: right
    );

    assign gamemode_led = dir;
endmodule