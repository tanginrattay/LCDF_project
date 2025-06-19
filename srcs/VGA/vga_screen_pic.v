/*
 * Module name: vga_screen_pic
 * Function description:
 *   Generates VGA pixel color signals based on the output of game_logic, implementing the display of background, obstacles, and player.
 *   The screen resolution is 640*480, pixel coordinates range from 0-639 (x) and 0-479 (y).
 * Inputs:
 *   pix_x       - Current pixel x coordinate
 *   pix_y       - Current pixel y coordinate
 *   gamemode    - Game mode (from game_logic)
 *   player_y    - Player Y coordinate (from game_logic)
 *   obstacle_x  - X coordinates of 10 obstacles, each 20 bits (left 10 + right 10), total 200 bits
 *   obstacle_y  - Y coordinates of 10 obstacles, each 18 bits (top 9 + bottom 9), total 180 bits
 * Outputs:
 *   rgb         - Current pixel color (12 bits, R[11:8], G[7:4], B[3:0])
 */

module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire [1:0] gamemode,
    input wire [8:0] player_y,
    input wire [59:0] obstacle_x,
    input wire [53:0] obstacle_y,
    output reg [11:0] rgb // Changed to 12-bit output
);

    parameter PLAYER_X = 160;
    parameter PLAYER_SIZE = 40;
    parameter UPPER_BOUND = 20;
    parameter LOWER_BOUND   = 460;
    parameter DEFAULT_COLOR = 12'b0000_0000_0000; // Default color

    integer i;
    reg player_region;
    reg obstacle_region;
    reg [9:0] obs_x_left, obs_x_right;
    reg [8:0] obs_y_top, obs_y_bottom;
    reg out_bound_y; // y coordinate boundary check

    always @(*) begin
        // Boundary check
        out_bound_y = (pix_y <= UPPER_BOUND) | (pix_y >= LOWER_BOUND);

        // Default background color
        case (gamemode)
            2'b00: rgb = 12'b0000_1111_0000; // Initial: green
            2'b01: rgb = 12'b1111_1111_1111; // In-game: white
            2'b10: rgb = 12'b1111_1111_0000; // Paused: yellow
            2'b11: rgb = 12'b1111_0000_0000; // Ended: red
            default: rgb = DEFAULT_COLOR;
        endcase
        // Change game background color based on gamemode
        if(gamemode == 2'b00)begin
            player_region = 1'b0;
            obstacle_region = 1'b0;
        end
        else begin
            // Player region check
            player_region = (pix_x >= PLAYER_X) && (pix_x < PLAYER_X + PLAYER_SIZE) &&
                            (pix_y >= player_y) && (pix_y < player_y + PLAYER_SIZE);

            // Obstacle region check
            obstacle_region = 1'b0;
            for (i = 0; i < 3; i = i + 1) begin
                obs_x_left   = obstacle_x[i*10 +: 10];
                obs_x_right  = obs_x_left + 10'd40; // Assume obstacle width is 40
                obs_y_top    = obstacle_y[i*9 +: 9];
                obs_y_bottom = obs_y_top + 9'd40; // Assume obstacle height is 40
                if (!(obs_x_left == obs_x_right && obs_y_top == obs_y_bottom)) begin
                    if (pix_x >= obs_x_left && pix_x < obs_x_right &&
                        pix_y >= obs_y_top && pix_y < obs_y_bottom) begin
                        obstacle_region = 1'b1;
                    end
                end
            end

            // Priority: player > obstacle > background
            if (obstacle_region) begin
                rgb = 12'b1111_0111_0000; // Orange
            end
            if (player_region) begin
                rgb = 12'b0000_0000_1111; // Blue
            end
        end
        if (out_bound_y)begin
            rgb = DEFAULT_COLOR; // Default color
        end
    end

endmodule
