module top(
    input wire clk,          
    input wire RST_n,        
    input wire [2:0] btn,    
    output wire [3:0] R,     
    output wire [3:0] G,     
    output wire [3:0] B,     
    output wire HS,          
    output wire VS,          
    output wire buzzer       
);

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
    wire [199:0] obstacle_x;      
    wire [179:0] obstacle_y;      

    Anti_jitter mo(clk, btn[0], btn_ok[0]);
    Anti_jitter mo(clk, btn[1], btn_ok[1]);
    Anti_jitter mo(clk, btn[2], btn_ok[2]);
    Anti_jitter mo(clk, RST_n, rst_n);

    game_logic u_game_logic (
        .rst_n(rst_n),
        .btn(btn_ok),
        .clk(clk_60hz),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .btn_ok(btn_ok),
        .gamemode(gamemode),
        .player_y(player_y)
    );

    map u_map (
        .rst_n(rst_n),
        .clk(clk_60hz),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y)
    );

    image_display u_image_display (
        .rst_n(rst_n),
        .clock(clk_25mhz),       
        .player_y(player_y),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .gamemode(gamemode),
        .R(R),
        .G(G),
        .B(B),
        .HS(HS),
        .VS(VS)
    );

    buzzer_module u_buzzer (
        .rst_n(rst_n),
        .clk(clk),
        .gamemode(gamemode),
        .btn(btn_ok),
        .buzzer(buzzer)
    );

endmodule