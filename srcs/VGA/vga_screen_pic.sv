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

    // 优化：减少中间变量的使用，简化逻辑以减少时序问题
    always_comb begin
        // 默认背景色
        case (gamemode)
            2'b00:   rgb = 12'h0F0; // Initial: Green
            2'b01:   rgb = 12'hFFF; // In-game: White
            2'b10:   rgb = 12'hFF0; // Paused: Yellow
            2'b11:   rgb = 12'hF00; // Ended: Red
            default: rgb = DEFAULT_COLOR;
        endcase
        
        // 只在游戏进行时绘制游戏对象
        if (gamemode != 2'b00) begin
            // 检查是否在障碍物上（优化：直接在条件中计算）
            for (integer i = 0; i < 10; i = i + 1) begin
                if (pix_x >= obstacle_x[i][19:10] && pix_x < obstacle_x[i][9:0] &&
                    pix_y >= obstacle_y[i][17:9]  && pix_y < obstacle_y[i][8:0]) begin
                    rgb = 12'hFA0; // Obstacle: Orange
                end
            end
            
            // 检查是否在玩家上（优先级最高）
            if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                rgb = 12'h00F; // Player: Blue
            end
        end
        
        // 边界始终显示（最高优先级）
        if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
            rgb = DEFAULT_COLOR; // Border: Black
        end
    end

endmodule