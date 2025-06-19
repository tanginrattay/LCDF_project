`timescale 1ns/1ps

module screen_tb;
    reg [9:0] pix_x;
    reg [8:0] pix_y;
    reg [1:0] gamemode;
    reg [8:0] player_y;
    reg [199:0] obstacle_x;
    reg [179:0] obstacle_y;
    wire [11:0] rgb;

    // 实例化被测模块
    vga_screen_pic uut (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .gamemode(gamemode),
        .player_y(player_y),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .rgb(rgb)
    );


    integer f;
    //将这个文件设置为python代码的目录下
    initial f = $fopen("D:/Users/youngthen/Logic/lcdf/screen_pixels.txt", "w");

    initial begin
        // 设置测试参数
        gamemode = 2'b01;      // 游戏进行中
        player_y = 9'd200;     // 玩家Y坐标
        obstacle_x = 200'b0;   // 障碍物全为0（可根据需要修改）
        obstacle_y = 180'b0;

        // 扫描整个屏幕像素
        for (pix_y = 0; pix_y < 480; pix_y = pix_y + 1) begin
            for (pix_x = 0; pix_x < 640; pix_x = pix_x + 1) begin
                #1; // 等待组合逻辑稳定
                $fwrite(f, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
            end
        end

        $fclose(f);
        $stop;
    end

endmodule