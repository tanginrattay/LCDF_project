module tb_vga_screen_pic;

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

    // // 假设blk_mem_gen_0为行为模型，返回固定颜色
    // logic [11:0] game_start_data;
    // assign game_start_data = 12'hA5A; // 可根据需要修改

    // // 覆盖原始blk_mem_gen_0实例
    // bind vga_screen_pic blk_mem_gen_0 start1 (
    //     .clka(clk),
    //     .addra(),
    //     .douta(game_start_data)
    // );

    vga_screen_pic dut (
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

    // 时钟生成
    initial clk = 0;
    always #1 clk = ~clk;

    integer fp;

    initial begin
        // 初始化
        pix_x = 0;
        pix_y = 0;
        gamemode = 2'b00;
        player_y = 100;

            // 初始化障碍物
            for (int i = 0; i < 10; i++) begin
                obstacle_x_game_left[i]  = 100 + i*40;
                obstacle_x_game_right[i] = 140 + i*40;
                obstacle_y_game_up[i]    = 100 + i*20;
                obstacle_y_game_down[i]  = 140 + i*20;
            end

            fp = $fopen("D:/Users/youngthen/Logic/lcdf/screen_pixels.txt", "w");

        // 初始界面
            #10;
            for (int y = 0; y < 480; y += 1) begin
                for (int x = 0; x < 640; x += 1) begin
                    pix_x = x;
                    pix_y = y;
                    #1;
                    $fwrite(fp, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]);
                end
            end

        // // 游戏进行
        //     gamemode = 2'b01;
        //     #10;
        //     for (int y = 90; y < 160; y += 10) begin
        //         for (int x = 150; x < 250; x += 10) begin
        //             pix_x = x;
        //             pix_y = y;
        //             #1;
        //             $fwrite(fp, "Game: pix_x=%0d, pix_y=%0d, rgb=%h\n", pix_x, pix_y, rgb);
        //         end
        //     end

        // // 暂停
        //     gamemode = 2'b10;
        //     #10;
        //     pix_x = 200; pix_y = 120; #1;
        //     $fwrite(fp, "Pause: pix_x=%0d, pix_y=%0d, rgb=%h\n", pix_x, pix_y, rgb);

        // // 结束
        //     gamemode = 2'b11;
        //     #10;
        //     pix_x = 200; pix_y = 120; #1;
        //     $fwrite(fp, "End: pix_x=%0d, pix_y=%0d, rgb=%h\n", pix_x, pix_y, rgb);

        $fclose(fp);
        #10 $finish;
    end

endmodule