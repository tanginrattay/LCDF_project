/*
 * 模块名称: vga_screen_pic
 * 功能描述:
 *   根据game_logic的输出，生成VGA像素颜色信号，实现玩家、障碍物、背景的显示。
 *   屏幕是640*480分辨率，像素坐标范围为0-639（X）和0-479（Y）
 * 输入端口:
 *   pix_x       - 当前像素的X坐标
 *   pix_y       - 当前像素的Y坐标
 *   gamemode    - 游戏模式（来自game_logic）
 *   player_y    - 玩家Y坐标（来自game_logic）
 *   obstacle_x  - 10个障碍物的X坐标范围，每个20位（左10+右10），共200位
 *   obstacle_y  - 10个障碍物的Y坐标范围，每个18位（上9+下9），共180位
 * 输出端口:
 *   rgb         - 当前像素的颜色（12位，R[11:8], G[7:4], B[3:0]）
 */

module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    input wire [199:0] obstacle_x,
    input wire [179:0] obstacle_y,
    output reg [11:0] rgb // 修改为12位输出
);

    parameter PLAYER_X = 160;
    parameter PLAYER_SIZE = 40;
    parameter UPPER_BOUND = 40;
    parameter DEFAULT_COLOR = 12'b0000_0000_0000; // 黑色

    integer i;
    reg player_region;
    reg obstacle_region;
    reg [9:0] obs_x_left, obs_x_right;
    reg [8:0] obs_y_top, obs_y_bottom;
    reg out_bound_y; // y坐标边界检测

    always @(*) begin
        // 边界检测
        out_bound_y = (pix_y <= UPPER_BOUND);

        // 默认背景色
        case (gamemode)
            2'b00: rgb = 12'b0000_1111_0000; // 初始：绿色
            2'b01: rgb = 12'b1111_1111_1111; // 进行：白色
            2'b10: rgb = 12'b1111_1111_0000; // 暂停：黄色
            2'b11: rgb = 12'b1111_0000_0000; // 结束：红色
            default: rgb = DEFAULT_COLOR;
        endcase
        //根据gamemode更改游戏画面颜色判断逻辑
        if(gamemode == 2'b00)begin
            player_region = 1'b0;
            obstacle_region = 1'b0;
        end
        else begin
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
                rgb = 12'b1111_0111_0000; // 橙色
            end
            if (player_region) begin
                rgb = 12'b0000_0000_1111; // 蓝色
            end
        end
        if (out_bound_y)begin
            rgb = DEFAULT_COLOR; // 黑色
        end
    end

endmodule
