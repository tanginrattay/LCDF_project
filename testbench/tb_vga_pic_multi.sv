module tb_vga_pic_multi;

    // --- 信号定义 ---
    logic [9:0] pix_x;
    logic [8:0] pix_y;
    logic clk;
    logic [1:0] gamemode;
    logic [8:0] player_y;
    logic [2:0] heart;
    
    // 修正后的障碍物信号，与 vga_screen_pic.sv 模块匹配
    logic [9:0][1:0] obstacle_class;
    logic [9:0][9:0] obstacle_x_game_left;
    logic [9:0][2:0] width;
    logic [9:0][8:0] obstacle_y_game_up;
    logic [9:0][3:0] height;

    // 拖尾效果信号
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
        .width(width),
        .obstacle_y_game_up(obstacle_y_game_up),
        .height(height),
        .trail_x(trail_x),
        .trail_y(trail_y),
        .trail_life(trail_life),
        .rgb(rgb)
    );

    // --- 仿真参数 ---
    parameter UNIT_SIZE = 30; // 必须与设计模块中的 UNIT_SIZE 保持一致
    parameter NUM_FRAMES = 30;
    parameter OBSTACLE_SPEED = 4;
    parameter TRAIL_SPEED = 4;
    parameter PLAYER_INIT_Y = 200;
    parameter PLAYER_X = 200;
    parameter PLAYER_SIZE = 40; // 添加PLAYER_SIZE参数，需与设计模块一致

    // 时钟生成
    initial clk = 0;
    always #1 clk = ~clk; // 500MHz, 用于快速扫描像素

    initial begin
        string filename;
        integer fp;
        
        // --- 初始化 ---
        gamemode = 2'b01; // 游戏进行中
        player_y = PLAYER_INIT_Y;
        heart = 3'd5; // 初始5条命

        // 初始化多种障碍物
        for (int i = 0; i < 10; i++) begin
            obstacle_class[i] = i % 4; // 生成4种不同类型的障碍物 (0:小黑, 1:小白, 2:苦力怕, 3:僵尸)
            obstacle_x_game_left[i]  = 640 + i * 80; // 初始位置在屏幕右侧外
            obstacle_y_game_up[i]    = 100 + (i % 5) * 60; // 在不同Y坐标上错开
            width[i]  = (i % 2) + 1; // 宽度为 1 或 2 个单位
            height[i] = (i % 2) + 1; // 高度为 1 或 2 个单位
        end

        // 初始化拖尾效果 (全部清零)
        for (int i = 0; i < 41; i++) begin
            trail_x[i] = 0;
            trail_y[i] = 0;
            trail_life[i] = 0;
        end

        // --- 主循环：模拟多个帧的动态效果 ---
        for (int frame = 0; frame < NUM_FRAMES; frame = frame + 1) begin
            
            // 1. 更新游戏状态
            // 障碍物向左移动
            for (int i = 0; i < 10; i++) begin
                obstacle_x_game_left[i]  -= OBSTACLE_SPEED;
                // 如果障碍物完全移出左边界，则重置到右侧
                if ((obstacle_x_game_left[i] + width[i]*UNIT_SIZE) < 0) begin
                    obstacle_x_game_left[i]  = 640;
                end
            end

            // 玩家轻微上下移动
            player_y = PLAYER_INIT_Y + (frame % 20);

            // heart生命值递减演示
            heart = 5 - (frame / 6); // 每6帧减一颗心

            // 拖尾效果演示：在玩家左侧生成粒子
            for (int i = 0; i < 5; i++) begin
                automatic int trail_idx = (frame * 5 + i) % 41; // 循环使用trail数组
                trail_x[trail_idx] = PLAYER_X - 5;
                trail_y[trail_idx] = player_y + PLAYER_SIZE/2 + (i-2)*8; // 在玩家中心垂直散开
                trail_life[trail_idx] = 10; // 新粒子满生命值
            end
            // 所有粒子生命值随时间衰减
            for (int i = 0; i < 41; i++) begin
                if (trail_life[i] > 0) trail_life[i] -= 1;
            end

            // 2. 为当前帧生成图像文件
            filename = $sformatf("D:/Users/youngthen/Logic/lcdf/GIF/frame_%03d.txt", frame);
            fp = $fopen(filename, "w");
            $display("Generating frame %0d -> %s", frame, filename);
            
            // 扫描整个屏幕并写入像素数据
            for (int y = 0; y < 480; y++) begin
                for (int x = 0; x < 640; x++) begin
                    pix_x = x;
                    pix_y = y;
                    #2; // 等待组合逻辑稳定
                    $fwrite(fp, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);//bgr
                end
            end
            $fclose(fp);
        end

        #10 $finish;
    end

endmodule