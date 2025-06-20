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
    output reg [11:0] rgb
);
    // Game object constants
    parameter   PLAYER_X      = 160,
                PLAYER_SIZE   = 40,
                GAMEOVER_X    = 220,
                GAMEOVER_Y    = 140,
                UPPER_BOUND   = 20,
                LOWER_BOUND   = 460,
                DEFAULT_COLOR = 12'h000, // Black
                COLOR_INITIAL = 12'h0F0, // Green
                COLOR_INGAME  = 12'hFFF, // White  
                COLOR_PAUSED  = 12'hFF0, // Yellow
                COLOR_ENDED   = 12'hF00, // Blue
                COLOR_OBSTACLE = 12'hFA0, // Orange
                COLOR_PLAYER  = 12'h00F; // Blue

//TODO:这里的小图片还没用上
    parameter H_PIC = 10'd200, // over图片宽度
            SCREEN_W_PIC = 19'd640, // VGA 宽度
            PLAYER_PIC = 10'd40;
    
    wire [11:0] game_start_data,player_out_data,game_over_data; // Start screen data
    wire [18:0] pic_romaddrStart; // 大图片gamestart的 ROM 地址
    reg [15:0] pic_romaddrOver; //  小图片gameover的ROM地址
    reg [10:0] pic_romaddrPlayer; // Player的ROM地址
    assign pic_romaddrStart = pix_x + pix_y * SCREEN_W_PIC; // 大图片的宽度和 VGA 的宽度相同


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
    always_comb begin
        // Default background color
        case (gamemode)
            2'b00:   rgb = COLOR_INITIAL; // Initial: Green
            2'b01:   rgb = COLOR_INGAME; // In-game: White
            2'b10:   rgb = COLOR_PAUSED; // Paused: Yellow
            2'b11:   rgb = COLOR_ENDED; // Ended: Red
            default: rgb = DEFAULT_COLOR;
        endcase
        
        if (pix_x >= PLAYER_X && pix_x <= PLAYER_X + PLAYER_SIZE &&
                pix_y >= player_y && pix_y <= player_y + PLAYER_SIZE) begin
            pic_romaddrPlayer = ( pix_x - PLAYER_X) + ( pix_y - player_y ) * PLAYER_PIC;
        end
        if (pix_x - GAMEOVER_X >= 0 && pix_y - GAMEOVER_Y >= 0 )  begin
             pic_romaddrOver = ( pix_x - GAMEOVER_X) + ( pix_y - GAMEOVER_Y ) * H_PIC;
        end
        
        if(gamemode == 2'b00) begin
            rgb = game_start_data; // Display start screen data
        end

        // Only draw game objects during gameplay
        if (gamemode != 2'b00) begin
            // Check if on obstacle (optimization: calculate directly in condition)
            for (integer i = 0; i < 10; i = i + 1) begin
                if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i] &&
                    pix_y >= obstacle_y_game_up[i]  && pix_y < obstacle_y_game_down[i]) begin
                    rgb = COLOR_OBSTACLE; // Obstacle: Orange
                end
            end
            
            // Check if on player (highest priority)
            if (pix_x >= PLAYER_X && pix_x <= PLAYER_X + PLAYER_SIZE &&
                pix_y >= player_y && pix_y <= player_y + PLAYER_SIZE) begin
                rgb = player_out_data; // Player: Blue
            end
        end
        if( gamemode == 2'b11 && pix_x >= GAMEOVER_X && pix_x <= GAMEOVER_X + PLAYER_PIC &&
                pix_y >= GAMEOVER_Y && pix_y <= GAMEOVER_Y + H_PIC ) begin
            rgb = game_over_data;
        end

        
        // Border always displayed (highest priority)
        if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
            rgb = DEFAULT_COLOR; // Border: Black
        end
    end

endmodule
    