module tb_vga_pic;

    // --- 信号定义 ---
    logic [9:0] pix_x;
    logic [8:0] pix_y;
    logic clk;
    logic [1:0] gamemode;
    logic [8:0] player_y;
    
    // 新增/修改的信号，以匹配 vga_screen_pic 模块
    logic [2:0] heart;
    logic [9:0][1:0] obstacle_class;
    logic [9:0][9:0] obstacle_x_game_left;
    logic [9:0][9:0] obstacle_x_game_right;
    logic [9:0][8:0] obstacle_y_game_up;
    logic [9:0][8:0] obstacle_y_game_down;
    logic [40:0][9:0] trail_x;
    logic [40:0][8:0] trail_y;
    logic [40:0][3:0] trail_life;

    logic [11:0] rgb;

    // --- 模块实例化 (使用修正后的接口) ---
    vga_screen_pic simu (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode),
        .player_y(player_y),
        .heart(heart),
        .obstacle_class(obstacle_class),
        .obstacle_x_game_left(obstacle_x_game_left),
        .obstacle_x_game_right(obstacle_x_game_right),
        .obstacle_y_game_up(obstacle_y_game_up),
        .obstacle_y_game_down(obstacle_y_game_down),
        .trail_x(trail_x),
        .trail_y(trail_y),
        .trail_life(trail_life),
        .rgb(rgb)
    );

    // 时钟生成
    initial clk = 0;
    always #1 clk = ~clk; // 500MHz, 用于快速扫描像素

    integer fp;

    initial begin
        // --- 初始化 ---
        pix_x = 0;
        pix_y = 0;
        gamemode = 2'b01; // 设置为游戏进行中模式
        player_y = 200;   // 设置玩家Y坐标
        heart = 3'd4;     // 设置初始生命值为4

        // 初始化多种障碍物
        for (int i = 0; i < 10; i++) begin
            obstacle_class[i] = i % 4; // 生成4种不同类型的障碍物 (0:小黑, 1:小白, 2:苦力怕, 3:僵尸)
            obstacle_x_game_left[i]  = 100 + i * 50; // 障碍物水平错开
            obstacle_x_game_right[i] = obstacle_x_game_left[i] + 30; // 障碍物宽度为30
            obstacle_y_game_up[i]    = 100 + (i % 4) * 80; // 障碍物垂直错开
            obstacle_y_game_down[i]  = obstacle_y_game_up[i] + 30; // 障碍物高度为30
        end

        // 初始化拖尾效果 (在玩家身后生成一些粒子)
        for (int i = 0; i < 41; i++) begin
            if (i < 15) begin
                trail_x[i] = 160 - i*3; // 从玩家位置向左延伸
                trail_y[i] = player_y + 20 + (i % 5)*5 - 10; // 在玩家Y坐标附近上下波动
                trail_life[i] = 10 - (i/2); // 生命值从10递减，产生渐变效果
            end else begin
                trail_x[i] = 0;
                trail_y[i] = 0;
                trail_life[i] = 0;
            end
        end

        // 打开文件用于写入像素数据
        fp = $fopen("D:/Users/youngthen/Logic/lcdf/screen_pixels.txt", "w");

        // --- 生成一帧静态画面 ---
        #10; // 等待初始值稳定
        for (int y = 0; y < 480; y += 1) begin
            for (int x = 0; x < 640; x += 1) begin
                pix_x = x;
                pix_y = y;
                #2; // 等待组合逻辑输出稳定
                $fwrite(fp, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
            end
        end
        
        $fclose(fp);
        #10 $finish;
    end

endmodule