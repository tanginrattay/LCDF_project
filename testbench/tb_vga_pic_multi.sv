module tb_vga_pic_multi;

    // --- 信号和模块实例化 (与原来相同) ---
    logic [9:0] pix_x;
    logic [8:0] pix_y;
    logic clk;
    logic [1:0] gamemode;
    logic [8:0] player_y;
    logic [9:0][9:0] obstacle_x_game_left;
    logic [9:0][9:0] obstacle_x_game_right;
    logic [9:0][8:0] obstacle_y_game_up;
    logic [9:0][8:0] obstacle_y_game_down;
    logic [11:0] rgb;

    vga_screen_pic simu (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode),
        .player_y(player_y),
        .obstacle_x_game_left(obstacle_x_game_left),
        .obstacle_x_game_right(obstacle_x_game_right),
        .obstacle_y_game_up(obstacle_y_game_up),
        .obstacle_y_game_down(obstacle_y_game_down),
        .rgb(rgb)
    );

    // --- 仿真参数 ---
    parameter NUM_FRAMES = 30;      // 要生成的总帧数
    parameter OBSTACLE_SPEED = 4;   // 障碍物每帧移动的像素数

    // 时钟生成
    initial clk = 0;
    always #1 clk = ~clk; // 1ns周期，即500MHz时钟，用于快速扫描

    initial begin
        // --- 初始化游戏状态 ---
        gamemode = 2'b01; // 假设游戏一直在进行中
        player_y = 220;   // 玩家Y坐标固定

        // --- 初始化障碍物位置 (让它们从屏幕右侧开始) ---
        for (int i = 0; i < 10; i++) begin
            obstacle_x_game_left[i]  = 640 + i * 80; // 在屏幕右侧外 staggered 排列
            obstacle_x_game_right[i] = obstacle_x_game_left[i] + 40; // 障碍物宽度为40
            obstacle_y_game_up[i]    = 100 + i * 20;
            obstacle_y_game_down[i]  = obstacle_y_game_up[i] + 40; // 障碍物高度为40
        end

        // --- 主循环：模拟多个帧 ---
        for (int frame = 0; frame < NUM_FRAMES; frame = frame + 1) begin
            string filename;
            integer fp;

            // --- 1. 更新游戏逻辑：移动障碍物 (这是动态的核心) ---
            for (int i = 0; i < 10; i++) begin
                // 向左移动
                obstacle_x_game_left[i]  -= OBSTACLE_SPEED;
                obstacle_x_game_right[i] -= OBSTACLE_SPEED;

                // 如果障碍物完全移出左侧屏幕，则让它重新回到右侧
                if (obstacle_x_game_right[i] < 0) begin
                    obstacle_x_game_left[i]  = 640;
                    obstacle_x_game_right[i] = 640 + 40;
                end
            end

            // --- 2. 为当前帧生成图像文件 ---
            filename = $sformatf("D:/Users/youngthen/Logic/lcdf/GIF/frame_%03d.txt", frame);
            fp = $fopen(filename, "w");
            $display("Generating frame %0d -> %s", frame, filename);

            // 扫描整个屏幕，并将像素数据写入当前帧的文件
            for (int y = 0; y < 480; y = y + 1) begin
                for (int x = 0; x < 640; x = x + 1) begin
                    pix_x = x;
                    pix_y = y;
                    #2; // 等待2个时钟周期，确保组合逻辑稳定
                    $fwrite(fp, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
                end
            end

            $fclose(fp);
        end

        #10 $finish;
    end

endmodule