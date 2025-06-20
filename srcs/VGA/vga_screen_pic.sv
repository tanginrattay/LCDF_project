// File: vga_screen_pic.sv 
// Description: 优化的VGA显示模块，配合时钟域同步使用
//              进一步减少时序问题，提高显示稳定性

module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    
    input logic [9:0] [19:0] obstacle_x,
    input logic [9:0] [17:0] obstacle_y,
    
    output reg [11:0] rgb
);
    // Game object constants
    parameter PLAYER_X      = 160;
    parameter PLAYER_SIZE   = 40;
    parameter UPPER_BOUND   = 20;
    parameter LOWER_BOUND   = 460;
    parameter DEFAULT_COLOR = 12'h000; // Black
    
    // 颜色常量
    parameter COLOR_INITIAL = 12'h0F0; // Green
    parameter COLOR_INGAME  = 12'hFFF; // White  
    parameter COLOR_PAUSED  = 12'hFF0; // Yellow
    parameter COLOR_ENDED   = 12'hF00; // Red
    parameter COLOR_OBSTACLE = 12'hFA0; // Orange
    parameter COLOR_PLAYER  = 12'h00F; // Blue
    parameter COLOR_BORDER  = 12'h000; // Black
    
    // 预计算边界检查信号，减少组合逻辑延迟
    wire is_upper_border = (pix_y <= UPPER_BOUND);
    wire is_lower_border = (pix_y >= LOWER_BOUND);
    wire is_border = is_upper_border || is_lower_border;
    
    // 预计算玩家区域检查
    wire is_player_x = (pix_x >= PLAYER_X) && (pix_x < PLAYER_X + PLAYER_SIZE);
    wire is_player_y = (pix_y >= player_y) && (pix_y < player_y + PLAYER_SIZE);
    wire is_player = is_player_x && is_player_y;
    
    // 障碍物检查信号数组
    logic [9:0] is_obstacle;
    
    // 为每个障碍物生成检查信号
    genvar i;
    generate 
        for (i = 0; i < 10; i = i + 1) begin: obstacle_check
            assign is_obstacle[i] = (pix_x >= obstacle_x[i][19:10]) && 
                                  (pix_x < obstacle_x[i][9:0]) &&
                                  (pix_y >= obstacle_y[i][17:9]) && 
                                  (pix_y < obstacle_y[i][8:0]);
        end
    endgenerate
    
    // 任意障碍物检查
    wire any_obstacle = |is_obstacle;
    
    // 主要显示逻辑 - 优化优先级和时序
    always_comb begin
        // 最高优先级：边界
        if (is_border) begin
            rgb = COLOR_BORDER;
        end
        // 次高优先级：玩家（仅在游戏进行时显示）
        else if (gamemode != 2'b00 && is_player) begin
            rgb = COLOR_PLAYER;
        end
        // 第三优先级：障碍物（仅在游戏进行时显示）
        else if (gamemode != 2'b00 && any_obstacle) begin
            rgb = COLOR_OBSTACLE;
        end
        // 最低优先级：背景色
        else begin
            case (gamemode)
                2'b00:   rgb = COLOR_INITIAL; // Initial: Green
                2'b01:   rgb = COLOR_INGAME;  // In-game: White
                2'b10:   rgb = COLOR_PAUSED;  // Paused: Yellow
                2'b11:   rgb = COLOR_ENDED;   // Ended: Red
                default: rgb = DEFAULT_COLOR;
            endcase
        end
    end
    
endmodule