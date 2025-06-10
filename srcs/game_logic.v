module game_logic(
    input wire rst_n,
    input wire clk,
    input wire [1:0] dir,         // btn[0]: switch direction, btn[1]: start/pause, btn[2]: end/reset
    input wire [199:0] obstacle_x, // Obstacle x coordinates (10 obstacles, 20 bits each)
    input wire [179:0] obstacle_y, // Obstacle y coordinates (10 obstacles, 18 bits each)
    output reg [1:0] gamemode,    // Game mode: 00=initial, 01=in-game, 10=paused, 11=ended
    output reg [8:0] player_y     // Player y coordinate
);
    
    parameter UPER_BOUND = 0;
    parameter LOWER_BOUND = 480; // Assuming a 480p display
    parameter PLAYER_SIZE = 40; // Player size in pixels

    reg direction; // 0: down, 1: up


    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            gamemode <= 2'b00; // Reset to initial state
            player_y <= 240; // Reset player position
            direction <= 0; // Start moving down
        end else begin
            // Handle button presses based on the direction input
            case (dir)
                2'b00: begin
                    if (gamemode == 2'b00) begin
                        gamemode <= 2'b01; // Start game
                    end else if (gamemode == 2'b01) begin
                        gamemode <= 2'b10;
                    end
                end
                2'b01: begin 
                    direction <= ~direction; // Switch direction
                    player_y <= player_y + (direction ? -1 : 1); // Move player
                    if (player_y < UPER_BOUND) begin
                        player_y <= UPER_BOUND; // Prevent going out of bounds
                    end else if (player_y > LOWER_BOUND - PLAYER_SIZE) begin
                        player_y <= LOWER_BOUND - PLAYER_SIZE; // Prevent going out of bounds
                    end
                end
                2'b10: begin
                    if (gamemode == 2'b01) begin
                        gamemode <= 2'b11; // End game
                    end else if (gamemode == 2'b11) begin
                        gamemode <= 2'b00; // Reset to initial state
                        player_y <= 240; // Reset player position
                    end
                end
                default: begin
                    player_y <= player_y + (direction ? -1 : 1); // Move player
                    if (player_y < UPER_BOUND) begin
                        player_y <= UPER_BOUND; // Prevent going out of bounds
                    end else if (player_y > LOWER_BOUND - PLAYER_SIZE) begin
                        player_y <= LOWER_BOUND - PLAYER_SIZE; // Prevent going out of bounds
                    end
                end 
            endcase
        end
    end 
  

endmodule