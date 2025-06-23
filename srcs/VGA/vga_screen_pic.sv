module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire clk,
    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    input wire [2:0] heart,
    input logic [9:0] [9:0] obstacle_x_game_left,
    input logic [9:0] [9:0] obstacle_x_game_right,
    input logic [9:0] [8:0] obstacle_y_game_up,
    input logic [9:0] [8:0] obstacle_y_game_down,
    output reg [11:0] rgb
);
    // Game object constants (游戏对象常量)
    parameter   PLAYER_X        = 160,
                PLAYER_SIZE     = 40,
                GAMEOVER_X      = 220,
                GAMEOVER_Y      = 140,
                UPPER_BOUND     = 20,
                LOWER_BOUND     = 460,
                DEFAULT_COLOR   = 12'h000, // 
                COLOR_INITIAL   = 12'h0F0, // 
                COLOR_INGAME    = 12'hFFF, // 
                COLOR_PAUSED    = 12'hFF0, // 
                COLOR_ENDED     = 12'hFFF, // 
                COLOR_OBSTACLE  = 12'hFA0, // 
                COLOR_PLAYER    = 12'h00F; // 


    parameter H_PIC = 10'd200, // over图片宽度 (Game Over image width/height for square)
              SCREEN_W_PIC = 10'd640, // VGA 宽度 (VGA width)
              PLAYER_PIC = 10'd40, // Player image size
    // Heart image constants
              HEART_SIZE = 10'd16, // Heart图片的宽度
    // The first Heart image position constants
              HEART_Y = 10'd463,
              HEART_X = 10'd0;
    localparam SCROLL_SPEED = 4;

    // Wire declarations for ROM data (ROM数据线声明)
    wire [11:0] game_start_data, player_out_data, game_over_data, background_data, heart_data;
    // ROM address declarations (ROM地址声明)
    wire [18:0] pic_romaddrStart; // 大图片gamestart的 ROM 地址 (Start screen ROM address)
    reg [15:0] pic_romaddrOver; // 小图片gameover的ROM地址 (Game Over ROM address)
    reg [10:0] pic_romaddrPlayer; // Player的ROM地址 (Player ROM address)
    reg [18:0] pic_romaddrBackground;    
    reg [7:0] pic_romaddrHeart;

    // Instance of ROM blocks (ROM模块实例化)
    player player_rom (
      .clka(clk),
      .addra(pic_romaddrPlayer),
      .douta(player_out_data)
    );
    start game_start_rom (
      .clka(clk),
      .addra(pic_romaddrStart),
      .douta(game_start_data)
    );
    //   blk_mem_gen_3  game_over_rom (
   game_over  game_over_rom (
      .clka(clk),
      .addra(pic_romaddrOver),
      .douta(game_over_data)
    );
    background background_rom (
        .clka(clk),    // input wire clka
        .addra(pic_romaddrBackground),  // input wire [18 : 0] addra
        .douta(background_data)  // output wire [11 : 0] douta
    );
    heart heart_rom (
        .clka(clk),
        .addra(pic_romaddrHeart),
        .douta(heart_data)
    );

    assign pic_romaddrStart = pix_x + pix_y * SCREEN_W_PIC;
    assign pic_romaddrBackground = (pix_y >= UPPER_BOUND && pix_y < LOWER_BOUND) ?  pix_x  + (pix_y - UPPER_BOUND) * SCREEN_W_PIC : 0; // In-game background ROM address
    // 计算玩家和游戏结束图片的ROM地址
    always_comb begin
        pic_romaddrPlayer = (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                             pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) ?
                            (pix_x - PLAYER_X) + (pix_y - player_y) * PLAYER_PIC : 0; // Default to 0 if out of bounds
        pic_romaddrOver = (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                           pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) ?
                          (pix_x - GAMEOVER_X) + (pix_y - GAMEOVER_Y) * H_PIC : 0; // Default to 0 if out of bounds
    end

    always_comb begin
        // Heart ROM地址计算
        pic_romaddrHeart = 0; // 默认值
        
        // 计算当前像素是否落在某个心形图标区域内
        for (int h = 0; h < 5; h++) begin
            if (pix_y >= HEART_Y && pix_y < HEART_Y + HEART_SIZE && 
                pix_x >= HEART_X + h*HEART_SIZE && pix_x < HEART_X + (h+1)*HEART_SIZE) begin
                // 只显示小于等于heart值的心
                if (h < heart) begin
                    pic_romaddrHeart = (pix_x - (HEART_X + h*HEART_SIZE)) + 
                                       (pix_y - HEART_Y) * HEART_SIZE;
                end
            end
        end
    end

    // State signal for pixel type (像素类型状态信号)
    reg [3:0] pixel_state; // 4位宽可表示0-15的状态
    // 状态定义:
    //0: Border (边界)
    //1: Obstacle (障碍物)
    //2: Player (玩家)
    //3: Game Over image (游戏结束图片)
    //4: Game Over background (游戏结束背景)
    //5: In-game background (游戏内背景)
    //6: 初始画面
    //7: Paused screen (暂停画面)
    //8: 保留
    //9: Heart (心形图标)
    integer i;

    always_comb begin
        pixel_state = 4'd0; // Default to background (默认为背景)
        if (gamemode == 2'b00) begin
                pixel_state = 4'd6; //(初始画面)
            end
        // 如果不是Heart，再检查其他状态
        else begin
            for (int h = 0; h < 5; h++) begin
                if (pix_y >= HEART_Y && pix_y < HEART_Y + HEART_SIZE && 
                    pix_x >= HEART_X + h*HEART_SIZE && pix_x < HEART_X + (h+1)*HEART_SIZE && 
                    h < heart) begin
                    pixel_state = 4'd9; // Heart状态
                    break;
                end
            end
            if (pixel_state != 4'd9) begin
                if (gamemode == 2'b01) begin
                    if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                        pixel_state = 4'd0; // Border (边界)
                    end
                    else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                            pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                        pixel_state = 4'd2; // Player (玩家)
                    end
                    else begin
                        for (i = 0; i < 10; i = i + 1) begin
                            if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i] &&
                                pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                                pixel_state = 4'd1; //障碍物
                                break; //找到障碍物，无需检查其他
                            end
                        end
                    if (pixel_state == 4'd0) begin
                            pixel_state = 4'd5;//游戏内背景
                        end
                    end
                end
                else if (gamemode == 2'b11) begin
                    if (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                        pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) begin
                        pixel_state = 4'd3; 
                    end// Game Over image (游戏结束图片)
                    else if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                        pixel_state = 4'd0; 
                    end//边界 
                    else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                            pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                        pixel_state = 4'd2; 
                    end// Player (玩家)
                    else begin
                        for (i = 0; i < 10; i = i + 1) begin
                            if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i] &&
                                pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                                pixel_state = 4'd1; //障碍物
                                break; //找到障碍物，无需检查其他
                            end
                        end
                        if (pixel_state == 4'd0) begin
                            pixel_state = 4'd4; //TODO
                        end
                    end
                end//结束
                else if (gamemode == 2'b10) begin
                    pixel_state = 4'd7;
                end //TODO:暂停画面
                // Default (默认)
                else begin
                    pixel_state = 4'd0; //黑色背景
                end
            end
        end
    end //end pixel_state detection

    //根据游戏模式和像素状态赋值RGB颜色
    always_comb begin
        case (gamemode)
            2'b00: begin // 初始游戏模式
                    rgb = game_start_data;
            end
            2'b01: begin // 游戏进行模式
                case (pixel_state)
                    3'd0: rgb = DEFAULT_COLOR; // Border (边界) or Default (默认)
                    3'd1: rgb = COLOR_OBSTACLE; // Obstacle (障碍物)
                    3'd2: rgb = player_out_data; // Player (玩家)
                    3'd5: rgb = background_data; // In-game background (游戏内背景)
                    3'd9: rgb = heart_data; // TODO显示心形图标
                    default: rgb = DEFAULT_COLOR; // Fallback (回退)
                endcase
            end
            2'b10: begin //暂停模式
                if (pixel_state == 4'd9)
                    rgb = heart_data; // 显示心形图标
                else
                    rgb = COLOR_PAUSED;
            end
            2'b11: begin //游戏结束模式
                case (pixel_state)
                    4'd0: rgb = DEFAULT_COLOR; //边界
                    4'd1: rgb = COLOR_OBSTACLE; // Obstacle (障碍物)
                    4'd2: rgb = player_out_data; // Player (玩家)
                    4'd3: rgb = game_over_data; //游戏结束图片
                    4'd4: rgb = COLOR_ENDED; //游戏结束背景
                    4'd9: rgb = heart_data; // 显示心形图标
                    default: rgb = DEFAULT_COLOR; //回退
                endcase
            end
            default: rgb = DEFAULT_COLOR;
        endcase
    end
endmodule