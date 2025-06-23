module tb_vga_pic;

    logic [9:0] pix_x;
    logic [8:0] pix_y;
    logic clk;
    logic [1:0] gamemode;
    logic [8:0] player_y;
    logic [2:0] heart;  // 添加heart信号
    
    // 替换旧的障碍物信号
    logic [9:0][1:0] obstacle_class;  // 障碍物类型
    logic [9:0][9:0] obstacle_x_game_left;
    logic [9:0][2:0] width;  // 替代obstacle_x_game_right
    logic [9:0][8:0] obstacle_y_game_up;
    logic [9:0][3:0] height;  // 替代obstacle_y_game_down
    
    // 添加拖尾效果信号
    logic [40:0][9:0] trail_x;
    logic [40:0][8:0] trail_y;
    logic [40:0][3:0] trail_life;
    
    logic [11:0] rgb;

    // 修改模块实例化，添加新的接口连接
    vga_screen_pic simu (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode),
        .player_y(player_y),
        .heart(heart),
        .obstacle_class(obstacle_class),
        .obstacle_x_game_left(obstacle_x_game_left),
        .width(width),
        .obstacle_y_game_up(obstacle_y_game_up),
        .height(height),
        .trail_x(trail_x),
        .trail_y(trail_y),
        .trail_life(trail_life),
        .rgb(rgb)
    );

    // 定义障碍物参数
    parameter UNIT_SIZE = 30;

    // 时钟生成
    initial clk = 0;
    always #1 clk = ~clk;

    integer fp;

    initial begin
        // 初始化基本信号
        pix_x = 0;
        pix_y = 0;
        gamemode = 2'b01;  // 游戏进行中
        player_y = 100;
        heart = 3'd4;      // 显示4颗心
        
        // 初始化障碍物 - 添加不同类型
        for (int i = 0; i < 10; i++) begin
            // 每种障碍物类型都显示
            obstacle_class[i] = i % 4;  // 0=小黑, 1=小白, 2=苦力怕, 3=僵尸
            
            // 设置它们的位置和尺寸，错开放置
            obstacle_x_game_left[i] = 100 + i*60;
            width[i] = 1 + (i % 3);  // 宽度1-3个单位
            obstacle_y_game_up[i] = 80 + (i % 5)*60;
            height[i] = 1 + (i % 2);  // 高度1-2个单位
        end
        
        // 初始化拖尾效果
        for (int i = 0; i < 41; i++) begin
            if (i < 15) begin
                // 生成一些拖尾粒子在玩家后面
                trail_x[i] = 150 - i*3;  // 从玩家位置往左
                trail_y[i] = player_y + 20 + (i % 5)*5 - 10;  // 上下波动
                trail_life[i] = 10 - (i/2);  // 生命值从10递减
            end else begin
                trail_x[i] = 0;
                trail_y[i] = 0;
                trail_life[i] = 0;
            end
        end

        // 输出文件设置
        fp = $fopen("D:/Users/youngthen/Logic/lcdf/screen_pixels.txt", "w");
        
        // 生成游戏画面 - 扫描所有像素并输出
        #10;
        for (int y = 0; y < 480; y += 1) begin
            for (int x = 0; x < 640; x += 1) begin
                pix_x = x;
                pix_y = y;
                #1;
                $fwrite(fp, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
            end
        end
        
        $fclose(fp);
        #10 $finish;
    end

endmodule