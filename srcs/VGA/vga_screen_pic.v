/*
 * 模块名称: vga_screen_pic
 * 功能描述:
 *   根据game_logic的输出，生成VGA像素颜色信号，实现玩家、障碍物、背景的显示。
 * 输入端口:
 *   pix_x       - 当前像素的X坐标
 *   pix_y       - 当前像素的Y坐标
 *   gamemode    - 游戏模式（来自game_logic）
 *   player_y    - 玩家Y坐标（来自game_logic）
 *   obstacle_x  - 10个障碍物的X坐标范围，每个20位（左10+右10），共200位
 *   obstacle_y  - 10个障碍物的Y坐标范围，每个18位（上9+下9），共180位
 * 输出端口:
 *   rgb         - 当前像素的颜色（8位：R[7:5], G[4:2], B[1:0]）
 */

module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    input wire [199:0] obstacle_x,
    input wire [179:0] obstacle_y,
    output reg [7:0] rgb
);

    parameter PLAYER_X = 160;
    parameter PLAYER_SIZE = 40;

    integer i;
    reg player_region;
    reg obstacle_region;
    reg [9:0] obs_x_left, obs_x_right;
    reg [8:0] obs_y_top, obs_y_bottom;

    always @(*) begin
        // 默认背景色
        case (gamemode)
            2'b00: rgb = 8'b110_110_11; // 初始：浅蓝
            2'b01: rgb = 8'b000_111_00; // 进行：绿色
            2'b10: rgb = 8'b111_111_00; // 暂停：黄色
            2'b11: rgb = 8'b111_000_00; // 结束：红色
            default: rgb = 8'b000_000_00;
        endcase

        // 玩家区域检测
        player_region = (pix_x >= PLAYER_X) && (pix_x < PLAYER_X + PLAYER_SIZE) &&
                        (pix_y >= player_y) && (pix_y < player_y + PLAYER_SIZE);

        // 障碍物区域检测
        obstacle_region = 1'b0;
        for (i = 0; i < 10; i = i + 1) begin
            obs_x_left   = obstacle_x[i*20 +: 10];
            obs_x_right  = obstacle_x[i*20+10 +: 10];
            obs_y_top    = obstacle_y[i*18 +: 9];
            obs_y_bottom = obstacle_y[i*18+9 +: 9];
            if (!(obs_x_left == obs_x_right && obs_y_top == obs_y_bottom)) begin
                if (pix_x >= obs_x_left && pix_x < obs_x_right &&
                    pix_y >= obs_y_top && pix_y < obs_y_bottom) begin
                    obstacle_region = 1'b1;
                end
            end
        end

        // 优先级：玩家 > 障碍物 > 背景
        if (obstacle_region) begin
            rgb = 8'b111_011_00; // 橙色
        end
        if (player_region) begin
            rgb = 8'b000_000_11; // 蓝色
        end
    end

endmodule
