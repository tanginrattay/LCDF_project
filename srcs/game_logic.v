module game_logic(
    input wire rst_n,
    input wire clk,
    input sw,
    input wire [2:0] btn,         // btn[0]: switch direction, btn[1]: start/pause, btn[2]: end/reset
    input wire [199:0] obstacle_x, // Obstacle x coordinates (10 obstacles, 20 bits each)
    input wire [179:0] obstacle_y, // Obstacle y coordinates (10 obstacles, 18 bits each)
    output reg [1:0] gamemode,    // Game mode: 00=initial, 01=in-game, 10=paused, 11=ended
    output reg [8:0] player_y     // Player y coordinate
);

    parameter UPER_BOUND = 0;
    parameter LOWER_BOUND = 480;
    parameter PLAYER_SIZE = 40;

    initial begin
        gamemode = 2'b00; // Initial state
        player_y = 240; // Start in the middle of the screen
    end

    always @(posedge btn[0]) begin 
        gamemode <= gamemode + 1'b1; // Start the game when btn[0] is pressed
    end 
    always @(posedge clk) begin
        if (gamemode == 2'b01) begin
            player_y <= player_y + (sw ? -1 : 1); // Move player
            if (player_y < UPER_BOUND) begin
                player_y <= UPER_BOUND; // Prevent going out of bounds
            end else if (player_y > LOWER_BOUND - PLAYER_SIZE) begin
                player_y <= LOWER_BOUND - PLAYER_SIZE; // Prevent going out of bounds
            end
        end
endmodule