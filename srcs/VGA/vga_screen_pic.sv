module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire clk,

    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    input wire [2:0] heart, //一共有5条命

    input logic [9:0] [1:0] obstacle_class, 
    input logic [9:0] [9:0] obstacle_x_game_left,
    input logic [9:0] [9:0] obstacle_x_game_right,
    input logic [9:0] [8:0] obstacle_y_game_up,
    input logic [9:0] [8:0] obstacle_y_game_down,
    // Trail effect inputs
    input logic [40:0] [9:0] trail_x,
    input logic [40:0] [8:0] trail_y,
    input logic [40:0] [3:0] trail_life,

    output reg [11:0] rgb //这里是bgr的依次输出
);

//参量说明    
    // Game object constants (游戏对象常量)
    parameter   PLAYER_X        = 160,
                PLAYER_SIZE     = 40,
                GAMEOVER_X      = 220,
                GAMEOVER_Y      = 140,
                UPPER_BOUND     = 20,
                LOWER_BOUND     = 460;
    parameter   DEFAULT_COLOR   = 12'h000,  
                COLOR_INITIAL   = 12'h0F0,  
                COLOR_INGAME    = 12'hFFF,  
                COLOR_PAUSED    = 12'hFF0,  
                COLOR_ENDED     = 12'hFFF,  
                COLOR_OBSTACLE  = 12'hFA0,  
                COLOR_PLAYER    = 12'h00F;  
    // Trail effect constants (拖尾效果常量)
    parameter   TRAIL_SIZE      = 4,        // Trail particle size
                TRAIL_BASE_COLOR = 12'h44F, // Base trail color (darker blue)
                TRAIL_FADE_LEVELS = 10;     // Number of fade levels
    parameter H_PIC = 10'd200, // over图片宽度 (Game Over image width/height for square)
              SCREEN_W_PIC = 10'd640, // VGA 宽度 (VGA width)
              PLAYER_PIC = 10'd40; // Player image size
    //HEART参量
    parameter HEART_SIZE = 10'd18, // Heart图片的宽度
              // 第一张图片的位置                      
              HEART_Y = 10'd460,
              HEART_X = 10'd0,
              MAX_HEART = 5; // 最大心形数量
    parameter UNIT_SIZE = 30;

    // --- 新增：定义一个将RGB转换为BGR的宏 ---
    `define RGB_TO_BGR(color) {color[3:0], color[7:4], color[11:8]}

//ROM数据线声明
    wire [11:0] game_start_data, player_out_data, game_over_data, background_data, heart_data;
    // 添加障碍物ROM数据线
    wire [11:0] black_data, skeleton_data, crepper_data, zomber_data;

    reg [18:0] pic_romaddrStart; // 大图片gamestart的 ROM 地址 (Start screen ROM address)
    
    reg [15:0] pic_romaddrOver; // 小图片gameover的ROM地址 (Game Over ROM address)
    reg [10:0] pic_romaddrPlayer; // Player的ROM地址 (Player ROM address)
    reg [18:0] pic_romaddrBackground;    
    reg [9:0] pic_romaddrHeart;
    reg [9:0] pic_romaddrBlack;    // 小黑地址寄存器
    reg [9:0] pic_romaddrSkeleton; // 小白地址寄存器 
    reg [9:0] pic_romaddrCrepper;  // 苦力怕地址寄存器
    reg [9:0] pic_romaddrZomber;   // 僵尸地址寄存器

    // Trail effect variables (拖尾效果变量)
    reg [3:0] trail_alpha; // Current trail alpha value
    reg [11:0] trail_color; // Current trail color
    reg trail_hit; // Flag indicating if current pixel hits any trail
    integer trail_idx; // Trail index for current pixel

//rom模块
    StevePlayer player_rom (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrPlayer),  // input wire [10 : 0] addra
      .douta(player_out_data)  // output wire [11 : 0] douta
    );
    start game_start (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrStart),  // input wire [18 : 0] addra
      .douta(game_start_data)  // output wire [11 : 0] douta
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
    Heart heart_rom (
        .clka(clk),
        .addra(pic_romaddrHeart),
        .douta(heart_data)
    );
    black black_rom (
        .clka(clk),
        .addra(pic_romaddrBlack),  // 连接地址寄存器
        .douta(black_data)         // 连接到数据线而非直接连rgb
    );//小黑
    skeleton skeleton_rom (
        .clka(clk),
        .addra(pic_romaddrSkeleton),
        .douta(skeleton_data)
    );
    crepper crepper_rom (
        .clka(clk),
        .addra(pic_romaddrCrepper),
        .douta(crepper_data)
    );
    zomber zomber_rom (
        .clka(clk),
        .addra(pic_romaddrZomber),
        .douta(zomber_data)
    );//僵尸

//计算rom地址
    always_comb begin
        pic_romaddrBackground = (pix_y >= UPPER_BOUND && pix_y < LOWER_BOUND) ?  pix_x  + (pix_y - UPPER_BOUND) * SCREEN_W_PIC : 0; // In-game background ROM address
        pic_romaddrStart = pix_x + pix_y * SCREEN_W_PIC;
        pic_romaddrPlayer = (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                             pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) ?
                            (pix_x - PLAYER_X) + (pix_y - player_y) * PLAYER_PIC : 0; // Default to 0 if out of bounds
        pic_romaddrOver = (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                           pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) ?
                          (pix_x - GAMEOVER_X) + (pix_y - GAMEOVER_Y) * H_PIC : 0; // Default to 0 if out of bounds
        pic_romaddrHeart = 0;
        for (int h = 0; h < MAX_HEART; h++) begin
            if (pix_y >= HEART_Y && pix_y < HEART_Y + HEART_SIZE && 
                pix_x >= HEART_X + h*HEART_SIZE && pix_x < HEART_X + (h+1)*HEART_SIZE && h < heart) begin
            pic_romaddrHeart = (pix_x - (HEART_X + h*HEART_SIZE)) + (pix_y - HEART_Y) * HEART_SIZE;
            end
        end
        // 计算障碍物的ROM地址
        pic_romaddrBlack = 0;
        pic_romaddrSkeleton = 0;
        pic_romaddrCrepper = 0;
        pic_romaddrZomber = 0;
        for (int j = 0; j < 10; j = j + 1) begin
            if (pix_x >= obstacle_x_game_left[j] && pix_x < obstacle_x_game_right[j] &&
            pix_y >= obstacle_y_game_up[j] && pix_y < obstacle_y_game_down[j]) begin
            
                // 计算障碍物内的相对坐标
                automatic logic [9:0] rel_x = pix_x - obstacle_x_game_left[j];
                automatic logic [8:0] rel_y = pix_y - obstacle_y_game_up[j];
                
                // 缩放到单元格内坐标(0-29)
                automatic logic [4:0] unit_x = rel_x % UNIT_SIZE;
                automatic logic [4:0] unit_y = rel_y % UNIT_SIZE;
                
                // 根据障碍物类型计算ROM地址
                case (obstacle_class[j])
                    2'd0: pic_romaddrBlack = unit_x + unit_y * UNIT_SIZE;    // 小黑
                    2'd1: pic_romaddrSkeleton = unit_x + unit_y * UNIT_SIZE; // 小白 
                    2'd2: pic_romaddrCrepper = unit_x + unit_y * UNIT_SIZE;  // 苦力怕
                    2'd3: pic_romaddrZomber = unit_x + unit_y * UNIT_SIZE;   // 僵尸
                endcase
                break; // 找到一个障碍物后停止搜索
            end
        end
    end
//拖尾效果计算    
    always_comb begin
        trail_hit = 1'b0;
        trail_alpha = 4'd0;
        trail_idx = 0;
        // Check all trail particles to see if current pixel hits any
        for (integer i = 0; i < 41; i = i + 1) begin
            // Use center as reference, so calculate left/top and right/bottom
            if (trail_life[i] > 0 &&
                pix_x >= (trail_x[i] - TRAIL_SIZE/2) && pix_x < (trail_x[i] + (TRAIL_SIZE+1)/2) &&
                pix_y >= (trail_y[i] - TRAIL_SIZE/2) && pix_y < (trail_y[i] + (TRAIL_SIZE+1)/2)) begin
                trail_hit = 1'b1;
                trail_alpha = trail_life[i]; // Use life as alpha intensity
                trail_idx = i;
                break; // Use first hit trail (highest priority)
            end
        end
    end
//基于生命值的拖尾颜色计算
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

//像素类型状态信号
    reg [3:0] pixel_state;  // Changed from [2:0] to [3:0]
    integer i;
    //确定当前像素的状态
    //0: Border (边界)
    //1: Obstacle (障碍物)
    //2:史蒂夫
    //3: Game Over image (游戏结束图片)
    //4: Game Over background (游戏结束背景)
    //5: In-game background (游戏内背景)
    //6: 初始画面
    //7: Paused screen (暂停画面)
    //8: Trail particle (拖尾粒子) - New state
    //9: Heart (心形图标)
    //10: 障碍物-小黑  obstacle_class = 2'd0
    //11: 障碍物-小白   obstacle_class = 2'd1
    //12: 障碍物-苦力怕 obstacle_class = 2'd2
    //13: 障碍物-僵尸 obstacle_class = 2'd3
//判断像素状态
    always_comb begin
        pixel_state = 4'd0; // Default to background (默认为背景)
        if (gamemode == 2'b00) begin
                pixel_state = 4'd6; //(初始画面)
            end
        else begin
            if(heart != 0) begin
                for (int h = 0; h < MAX_HEART; h++) begin
                    if (pix_y >= HEART_Y && pix_y < HEART_Y + HEART_SIZE && 
                        pix_x >= HEART_X + h*HEART_SIZE && pix_x < HEART_X + (h+1)*HEART_SIZE && 
                        h < heart) begin
                        pixel_state = 4'd9; // Heart状态
                        break;
                    end
                end
            end
            // 如果不是heart，再判断其他
            if (pixel_state != 4'd9) begin
                if (gamemode == 2'b01 | gamemode == 2'b10) begin
                    if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                        pixel_state = 4'd0; // Border (边界)
                    end
                    else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                            pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                        pixel_state = 4'd2; // Player (玩家)
                    end
                    else begin
                        logic is_obstacle;
                        is_obstacle = 1'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            // 使用width和height参数计算障碍物边界
                            if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i]&&
                                pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                                
                                // 根据obstacle_class设置对应的状态
                                case (obstacle_class[i])
                                    2'd0: pixel_state = 4'd10;  // 小黑
                                    2'd1: pixel_state = 4'd11;  // 小白
                                    2'd2: pixel_state = 4'd12;  // 苦力怕
                                    2'd3: pixel_state = 4'd13;  // 僵尸
                                    default: pixel_state = 4'd1; // 默认障碍物
                                endcase
                                
                                is_obstacle = 1'b1;
                                break;
                            end
                        end

                        if (!is_obstacle) begin
                            if (trail_hit) pixel_state = 4'd8; // Trail particle
                            else pixel_state = 4'd5; // In-game background
                        end
                    end
                end
                else if (gamemode == 2'b11) begin
                    // Game Over图片
                    if (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                        pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) begin
                        pixel_state = 4'd3; 
                    end 
                    // 边界
                    else if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                        pixel_state = 4'd0; 
                    end 
                    // 玩家
                    else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                        pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                        pixel_state = 4'd2;
                    end 
                    // 障碍物和背景
                    else begin
                        logic is_obstacle;
                        is_obstacle = 1'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            // 使用width和height参数计算障碍物边界
                            if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i]&&
                                pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                                
                                // 根据obstacle_class设置对应的状态
                                case (obstacle_class[i])
                                    2'd0: pixel_state = 4'd10;  // 小黑
                                    2'd1: pixel_state = 4'd11;  // 小白
                                    2'd2: pixel_state = 4'd12;  // 苦力怕
                                    2'd3: pixel_state = 4'd13;  // 僵尸
                                    default: pixel_state = 4'd1; // 默认障碍物
                                endcase
                                
                                is_obstacle = 1'b1;
                                break;
                            end
                        end

                        if (!is_obstacle) begin
                            if (trail_hit) pixel_state = 4'd8; // Trail particle
                            else pixel_state = 4'd4; // Game over background
                        end
                    end
                end //end gamemode 2'b11
                else begin
                    pixel_state = 4'd0; //黑色背景
                end
            end
        end
    end //end pixel_state detection

// 修改RGB输出部分，处理不同类型障碍物的颜色
always_comb begin
    // Default to black
    rgb = `RGB_TO_BGR(DEFAULT_COLOR); // 使用宏
    case (gamemode)
        2'b00: begin // 初始游戏模式
                rgb = `RGB_TO_BGR(game_start_data); // 使用宏
        end
        2'b01, 2'b11, 2'b10: begin // 游戏进行模式和游戏结束模式
            case (pixel_state)
                4'd0: rgb = `RGB_TO_BGR(DEFAULT_COLOR);      // Border (边界) or Default (默认)
                4'd1: rgb = `RGB_TO_BGR(COLOR_OBSTACLE);     // 普通障碍物
                4'd2: rgb = `RGB_TO_BGR(player_out_data);    // Player (玩家)
                4'd3: rgb = `RGB_TO_BGR(game_over_data);     // 游戏结束图片
                4'd4: rgb = `RGB_TO_BGR(background_data);        // 游戏结束背景
                4'd5: rgb = `RGB_TO_BGR(background_data);    // In-game background (游戏内背景)
                4'd8: rgb = `RGB_TO_BGR(trail_color);        // Trail particle
                4'd9: rgb = `RGB_TO_BGR(heart_data);         // 心形图标
                // 障碍物类型对应ROM数据
                4'd10: rgb = `RGB_TO_BGR(black_data);    // 小黑 - 使用ROM数据
                4'd11: rgb = `RGB_TO_BGR(skeleton_data); // 小白 - 使用ROM数据
                4'd12: rgb = `RGB_TO_BGR(crepper_data);  // 苦力怕 - 使用ROM数据
                4'd13: rgb = `RGB_TO_BGR(zomber_data);   // 僵尸 - 使用ROM数据
                default: rgb = `RGB_TO_BGR(DEFAULT_COLOR);
            endcase
        end
        default: rgb = `RGB_TO_BGR(DEFAULT_COLOR);
    endcase
end
endmodule
