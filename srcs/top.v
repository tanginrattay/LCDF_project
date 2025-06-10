module top(
    input wire clk,          
    input wire RST_n,        
    input wire [2:0] btn,    
    output wire [3:0] R,     
    output wire [3:0] G,     
    output wire [3:0] B,     
    output wire HS,          
    output wire VS          
//    output wire buzzer       
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
    wire [199:0] obstacle_x;      
    wire [179:0] obstacle_y;      


    // VGA相关信号
    wire [9:0] pix_x;      // VGA 当前像素X坐标
    wire [8:0] pix_y;      // VGA 当前像素Y坐标
    wire [11:0] vga_data;  // VGA 像素颜色数据
    wire rdn;              // VGA 读使能信号

    Anti_jitter mo(clk, btn[0], btn_ok[0]);
    Anti_jitter m1(clk, btn[1], btn_ok[1]);
    Anti_jitter m2(clk, btn[2], btn_ok[2]);
    Anti_jitter m3(clk, RST_n, rst_n);

    game_logic u_game_logic (
        .rst_n(rst_n),
        .btn(btn_ok),
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


//    buzzer_module u_buzzer (
//        .rst_n(rst_n),
//        .clk(clk),
//        .gamemode(gamemode),
//        .btn(btn_ok),
//        .buzzer(buzzer)
//    );

    // VGA屏幕图像生成模块
    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .gamemode(gamemode),
        .player_y(player_y),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .rgb({vga_data[11:8], vga_data[7:4], vga_data[3:0]})  // 转换为12位RGB格式
    );

    // VGA控制器
    vga_ctrl u_vga_ctrl(
        .clk(clk_25mhz),      // 25MHz VGA时钟
        .rst(~rst_n),         // 高电平有效的复位信号
        .Din(vga_data),       // 像素数据输入
        .row(pix_y),          // 像素Y坐标
        .col(pix_x),          // 像素X坐标
        .rdn(rdn),            // 读使能信号
        .R(R),                // 红色分量输出
        .G(G),                // 绿色分量输出
        .B(B),                // 蓝色分量输出
        .HS(HS),             // 行同步信号
        .VS(VS)              // 场同步信号
    );

endmodule