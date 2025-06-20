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

    vga_screen_pic screen (
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

    // 鏃堕挓鐢熸垚
    initial clk = 0;
    always #1 clk = ~clk;

    integer fp;

    initial begin
        // 鍒濆鍖�
        pix_x = 0;
        pix_y = 0;
        gamemode = 2'b11;
        player_y = 100;

            // 鍒濆鍖栭殰纰嶇墿
            for (int i = 0; i < 10; i++) begin
                obstacle_x_game_left[i]  = 100 + i*40;
                obstacle_x_game_right[i] = 120 + i*40;
                obstacle_y_game_up[i]    = 100 + i*20;
                obstacle_y_game_down[i]  = 140 + i*20;
            end

            fp = $fopen("E:/study/vscode/python/screen_pixels.txt", "w");

        // 鍒濆鐣岄潰
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