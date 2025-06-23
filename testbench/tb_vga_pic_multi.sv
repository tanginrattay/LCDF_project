module tb_vga_pic_multi;

    // VGA像素坐标
    logic [9:0] pix_x;
    logic [8:0] pix_y;
    logic clk;
    logic [1:0] gamemode;
    logic [8:0] player_y;
    logic [2:0] heart;
    logic [9:0][9:0] obstacle_x_game_left;
    logic [9:0][9:0] obstacle_x_game_right;
    logic [9:0][8:0] obstacle_y_game_up;
    logic [9:0][8:0] obstacle_y_game_down;
    logic [40:0][9:0] trail_x;
    logic [40:0][8:0] trail_y;
    logic [40:0][3:0] trail_life;
    logic [11:0] rgb;

    vga_screen_pic simu (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode),
        .player_y(player_y),
        .heart(heart),
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
    always #1 clk = ~clk; // 100MHz

    // 仿真参数
    parameter NUM_FRAMES = 30;
    parameter OBSTACLE_SPEED = 4;
    parameter TRAIL_SPEED = 4;
    parameter PLAYER_INIT_Y = 200;

    initial begin
        string filename;
        integer fp;
        // 初始化
        gamemode = 2'b01; // 游戏进行
        player_y = PLAYER_INIT_Y;
        heart = 3'd5; // 5条命

        // 初始化障碍物
        for (int i = 0; i < 10; i++) begin
            obstacle_x_game_left[i]  = 640 + i * 60;
            obstacle_x_game_right[i] = obstacle_x_game_left[i] + 40;
            obstacle_y_game_up[i]    = 100 + i * 20;
            obstacle_y_game_down[i]  = obstacle_y_game_up[i] + 40;
        end

        // 初始化trail
        for (int i = 0; i < 41; i++) begin
            trail_x[i] = 0;
            trail_y[i] = 0;
            trail_life[i] = 0;
        end

        // 生成帧
        for (int frame = 0; frame < NUM_FRAMES; frame++) begin
            // 动态演示：障碍物移动，trail生成，heart递减
            for (int i = 0; i < 10; i++) begin
                obstacle_x_game_left[i]  -= OBSTACLE_SPEED;
                obstacle_x_game_right[i] -= OBSTACLE_SPEED;
                if (obstacle_x_game_right[i] < 0) begin
                    obstacle_x_game_left[i]  = 640;
                    obstacle_x_game_right[i] = 640 + 40;
                end
            end

            // 玩家上下移动
            player_y = PLAYER_INIT_Y + (frame % 20);

            // heart递减演示
            heart = 5 - (frame % 6);

            // trail演示：每帧在玩家左侧生成一组trail
            for (int i = 0; i < 41; i++) begin
                if (i < 5) begin
                    trail_x[i] = 160 - frame*TRAIL_SPEED;
                    trail_y[i] = player_y + i*8;
                    trail_life[i] = 10 - frame;
                end else begin
                    trail_life[i] = 0;
                end
            end

            // --- 2. 为当前帧生成图像文件 ---

            filename = $sformatf("D:/Users/youngthen/Logic/lcdf/GIF/frame_%03d.txt", frame);
            fp = $fopen(filename, "w");
            $display("Generating frame %0d -> %s", frame, filename);
            
            for (int y = 0; y < 480; y++) begin
                for (int x = 0; x < 640; x++) begin
                    pix_x = x;
                    pix_y = y;
                    #1;
                    $fwrite(fp, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
                end
            end
            $fclose(fp);
        end

        #10 $finish;
    end

endmodule