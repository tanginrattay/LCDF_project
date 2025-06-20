`timescale 1ns/1ps
module screen_tb;
    reg [9:0] pix_x;
    reg [8:0] pix_y;
    reg [1:0] gamemode;
    reg [8:0] player_y;
    logic [9:0] [9:0] obstacle_x_game_left;
    logic [9:0] [9:0] obstacle_x_game_right;
    logic [9:0] [8:0] obstacle_y_game_up;
    logic [9:0] [8:0] obstacle_y_game_down;
    wire [11:0] rgb;

    // 实例化被测模块
    vga_screen_pic uut (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .gamemode(gamemode),
        .player_y(player_y),
        .obstacle_x_game_left(obstacle_x_game_left),
        .obstacle_x_game_right(obstacle_x_game_right),
        .obstacle_y_game_up(obstacle_y_game_up),
        .obstacle_y_game_down(obstacle_y_game_down),
        .rgb(rgb)
    );

    integer f;
    //将这个文件设置为python代码的目录下
    initial f = $fopen("D:/Users/youngthen/Logic/lcdf/screen_pixels.txt", "w");

    initial begin
        // 设置测试参数
        gamemode = 2'b01;      // 游戏进行中
        player_y = 9'd200;     // 玩家Y坐标
        // // 初始化障碍物坐标
        for (int i = 0; i < 10; i++) begin
            if (i < 2) begin // 只有前2个障碍物是有效的，并设置它们的高度
            obstacle_x_game_left[i]  = 10'd20 + i * 100;         // 左边界
            obstacle_x_game_right[i] = 10'd20 + i * 100 + 10'd50; // 右边界 (+50宽度)
            obstacle_y_game_up[i]    = 9'd41 + i * 10;           // 上边界
            obstacle_y_game_down[i]  = 9'd41 + i * 10 + 9'd30;   // 下边界 (+30高度)
        end 
        else begin // 其余的障碍物设置到屏幕外，确保不会显示
            obstacle_x_game_left[i]  = 10'd1023;
            obstacle_x_game_right[i] = 10'd1023;
            obstacle_y_game_up[i]    = 9'd511;
            obstacle_y_game_down[i]  = 9'd511;
            end
        end
        // 扫描整个屏幕像素
        for (pix_y = 0; pix_y < 480; pix_y = pix_y + 1) begin
            for (pix_x = 0; pix_x < 640; pix_x = pix_x + 1) begin
                #1; // 等待组合逻辑稳定
                $fwrite(f, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
            end
        end
        $monitor("pix_x=%0d, pix_y=%0d, rgb=%h",pix_x, pix_y, rgb);
        $fclose(f);
        $stop;

    end

endmodule