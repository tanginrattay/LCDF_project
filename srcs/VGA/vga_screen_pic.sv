module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire clk,
    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    input logic [9:0] [9:0] obstacle_x_game_left,
    input logic [9:0] [9:0] obstacle_x_game_right,
    input logic [9:0] [8:0] obstacle_y_game_up,
    input logic [9:0] [8:0] obstacle_y_game_down,
    // Trail effect inputs
    input logic [27:0] [9:0] trail_x,
    input logic [27:0] [8:0] trail_y,
    input logic [27:0] [3:0] trail_life,
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

    // Trail effect constants (拖尾效果常量)
    parameter   TRAIL_SIZE      = 8,        // Trail particle size
                TRAIL_BASE_COLOR = 12'h44F, // Base trail color (darker blue)
                TRAIL_FADE_LEVELS = 10;     // Number of fade levels

    parameter H_PIC = 10'd200, // over图片宽度 (Game Over image width/height for square)
              SCREEN_W_PIC = 10'd640, // VGA 宽度 (VGA width)
              PLAYER_PIC = 10'd40; // Player image size

    // Wire declarations for ROM data (ROM数据线声明)
    wire [11:0] game_start_data, player_out_data, game_over_data;
    // ROM address declarations (ROM地址声明)
    wire [18:0] pic_romaddrStart; // 大图片gamestart的 ROM 地址 (Start screen ROM address)
    reg [15:0] pic_romaddrOver; // 小图片gameover的ROM地址 (Game Over ROM address)
    reg [10:0] pic_romaddrPlayer; // Player的ROM地址 (Player ROM address)

    // Trail effect variables (拖尾效果变量)
    reg [3:0] trail_alpha; // Current trail alpha value
    reg [11:0] trail_color; // Current trail color
    reg trail_hit; // Flag indicating if current pixel hits any trail
    integer trail_idx; // Trail index for current pixel

    // Instance of ROM blocks (ROM模块实例化)
    blk_mem_gen_1 player (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrPlayer),  // input wire [10 : 0] addra
      .douta(player_out_data)  // output wire [11 : 0] douta
    );

    blk_mem_gen_2 game_start (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrStart),  // input wire [18 : 0] addra
      .douta(game_start_data)  // output wire [11 : 0] douta
    );

    blk_mem_gen_3 game_over (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrOver),  // input wire [15 : 0] addra
      .douta(game_over_data)  // output wire [11 : 0] douta
    );

    // (直接赋值 pic_romaddrStart，因为它直接来源于 pix_x, pix_y 和 SCREEN_W_PIC)
    assign pic_romaddrStart = pix_x + pix_y * SCREEN_W_PIC;

    // (计算玩家和游戏结束图片的ROM地址。无论它们是否显示，这些地址都应被计算，
    // 因为 blk_mem_gen 模块会持续从这些地址读取数据。)
    always_comb begin
        pic_romaddrPlayer = (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                             pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) ?
                            (pix_x - PLAYER_X) + (pix_y - player_y) * PLAYER_PIC : 0; // Default to 0 if out of bounds
        pic_romaddrOver = (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                           pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) ?
                          (pix_x - GAMEOVER_X) + (pix_y - GAMEOVER_Y) * H_PIC : 0; // Default to 0 if out of bounds
    end

    // Trail detection logic (拖尾检测逻辑)
    always_comb begin
        trail_hit = 1'b0;
        trail_alpha = 4'd0;
        trail_idx = 0;
        
        // Check all trail particles to see if current pixel hits any
        for (integer i = 0; i < 28; i = i + 1) begin
            if (trail_life[i] > 0 && 
                pix_x >= trail_x[i] && pix_x < trail_x[i] + TRAIL_SIZE &&
                pix_y >= trail_y[i] && pix_y < trail_y[i] + TRAIL_SIZE) begin
                trail_hit = 1'b1;
                trail_alpha = trail_life[i]; // Use life as alpha intensity
                trail_idx = i;
                break; // Use first hit trail (highest priority)
            end
        end
    end

    // Trail color calculation based on life (基于生命值的拖尾颜色计算)
    always_comb begin
        case (trail_alpha)
            4'd10: trail_color = 12'hFDD; // Brightest trail (white)
            4'd9:  trail_color = 12'hEEF; // Very bright (light blue-white)
            4'd8:  trail_color = 12'hDDF; // Bright (light blue)
            4'd7:  trail_color = 12'hCCF; // Medium-bright (medium light blue)
            4'd6:  trail_color = 12'hBBE; // Medium (medium blue)
            4'd5:  trail_color = 12'hAAD; // Medium-dim (darker blue)
            4'd4:  trail_color = 12'h99C; // Dim (dark blue)
            4'd3:  trail_color = 12'h88B; // Very dim (very dark blue)
            4'd2:  trail_color = 12'h77A; // Almost invisible (extremely dark blue)
            4'd1:  trail_color = 12'h669; // Barely visible (near black)
            default: trail_color = 12'h000; // Invisible
        endcase
    end

    // State signal for pixel type (像素类型状态信号)
    reg [2:0] pixel_state;
    integer i;
    //确定当前像素的状态
    //0: Border (边界)
    //1: Obstacle (障碍物)
    //2: Player (玩家)
    //3: Game Over image (游戏结束图片)
    //4: Game Over background (游戏结束背景)
    //5: In-game background (游戏内背景)
    //6: 初始画面
    //7: Paused screen (暂停画面)
    //8: Trail particle (拖尾粒子) - New state
    always_comb begin
        pixel_state = 3'd5; // Default to in-game background

        //(初始画面)
        if (gamemode == 2'b00) begin
            pixel_state = 3'd6;
        end
        // In-game screen (游戏进行画面) - gamemode 2'b01
        else if (gamemode == 2'b01) begin
            if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                pixel_state = 3'd0; // Border
            end else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                     pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                pixel_state = 3'd2; // Player
            end else begin
                logic is_obstacle;
                is_obstacle = 1'b0;
                for (i = 0; i < 10; i = i + 1) begin
                    if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i] &&
                        pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                        is_obstacle = 1'b1;
                        break;
                    end
                end

                if (is_obstacle) begin
                    pixel_state = 3'd1; // Obstacle
                end else if (trail_hit) begin
                    pixel_state = 3'd8; // Trail particle
                end else begin
                    pixel_state = 3'd5; // In-game background
                end
            end
        end
        // Paused screen (暂停画面)
        else if (gamemode == 2'b10) begin
            pixel_state = 3'd7;
        end
        // Game over screen (游戏结束画面)
        else if (gamemode == 2'b11) begin
            if (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) begin
                pixel_state = 3'd3; // Game Over image
            end else if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                pixel_state = 3'd0; // Border
            end else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                       pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                pixel_state = 3'd2; // Player
            end else begin
                logic is_obstacle;
                is_obstacle = 1'b0;
                for (i = 0; i < 10; i = i + 1) begin
                    if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i] &&
                        pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                        is_obstacle = 1'b1;
                        break;
                    end
                end

                if (is_obstacle) begin
                    pixel_state = 3'd1; // Obstacle
                end else if (trail_hit) begin
                    pixel_state = 3'd8; // Trail particle
                end else begin
                    pixel_state = 3'd4; // Game over background
                end
            end
        end
    end //end pixel_state detection

    //根据游戏模式和像素状态赋值RGB颜色
    always_comb begin
        // Default to black
        rgb = DEFAULT_COLOR; 

        case (gamemode)
            2'b00: begin // Initial game mode (初始游戏模式)
                rgb = game_start_data;
            end
            2'b01: begin // In-game mode (游戏进行模式)
                case (pixel_state)
                    3'd0: rgb = DEFAULT_COLOR;    // Border
                    3'd1: rgb = COLOR_OBSTACLE;  // Obstacle
                    3'd2: rgb = player_out_data; // Player
                    3'd5: rgb = COLOR_INGAME;    // In-game background
                    3'd8: rgb = trail_color;     // Trail particle
                    default: rgb = COLOR_INGAME; // Fallback to in-game background
                endcase
            end
            2'b10: begin // Paused mode (暂停模式)
                rgb = COLOR_PAUSED;
            end
            2'b11: begin // Game over mode (游戏结束模式)
                case (pixel_state)
                    3'd0: rgb = DEFAULT_COLOR;    // Border
                    3'd1: rgb = COLOR_OBSTACLE;  // Obstacle
                    3'd2: rgb = player_out_data; // Player
                    3'd3: rgb = game_over_data;  // Game over image
                    3'd4: rgb = COLOR_ENDED;     // Game over background
                    3'd8: rgb = trail_color;     // Trail particle
                    default: rgb = COLOR_ENDED; // Fallback to game-over background
                endcase
            end
        endcase
    end
endmodule