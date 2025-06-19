module game_logic(
    input wire rst_n,
    input wire clk,
    input [2:0] sw,
    input wire [59:0] obstacle_x, // Obstacle x coordinates (10 obstacles, 20 bits each)
    input wire [53:0] obstacle_y, // Obstacle y coordinates (10 obstacles, 18 bits each)
    output wire [1:0] gamemode,    // Game mode: 00=initial, 01=in-game, 10=paused, 11=ended
    output reg [8:0] player_y      // Player y coordinate
);

    integer k;
    
    wire sw_n = ~sw[0];

    reg [8:0] velocity;           // Player velocity for movement
    reg [1:0] crash;              // 00: no crash; 11: crash happened
    reg velocity_direction;       // 0: up; 1: down 

    parameter UPPER_BOUND    = 20;
    parameter LOWER_BOUND   = 460;
    parameter PLAYER_SIZE   = 40;
    parameter PLAYER_X = 160;
    parameter MAX_VELOCITY  = 8;
    parameter ACCELERATION  = 1;

    assign gamemode = sw[2:1] | crash; // Game mode logic

    // Next velocity and direction calculation
    wire [8:0] velocity_next;
    wire velocity_direction_next;
    wire [8:0] player_y_next;

    // Velocity and direction update logic
    assign velocity_next = (gamemode == 2'b01) ? (
        (sw_n == velocity_direction) ? 
            ((velocity + ACCELERATION > MAX_VELOCITY) ? MAX_VELOCITY : velocity + ACCELERATION) :
            ((velocity < ACCELERATION) ? (ACCELERATION - velocity) : velocity - ACCELERATION)
    ) : 9'd0;

    assign velocity_direction_next = (gamemode == 2'b01) ? (
        (sw_n == velocity_direction) ? velocity_direction :
            ((velocity < ACCELERATION) ? ~velocity_direction : velocity_direction)
    ) : 1'b0;

    // Calculate next player y position
    wire [8:0] player_y_calc = velocity_direction_next ? player_y + velocity_next : player_y - velocity_next;
    assign player_y_next = (gamemode == 2'b01) ? (
        (player_y_calc < UPPER_BOUND) ? UPPER_BOUND :
        (player_y_calc > LOWER_BOUND - PLAYER_SIZE) ? (LOWER_BOUND - PLAYER_SIZE) :
        player_y_calc
    ) : player_y;

    // Main sequential logic
    always @(posedge clk) begin
        if (sw[2:1] == 2'b00) begin
            player_y           <= (LOWER_BOUND - UPPER_BOUND) / 2;
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
        end else begin
            player_y           <= player_y_next;
            velocity           <= velocity_next;
            velocity_direction <= velocity_direction_next;
            // Crash detection logic
            for (k = 0; k < 3; k = k + 1) begin
                 if (
                (PLAYER_X < obstacle_x[k * 10 +: 10] + 10'd40) &&
                (PLAYER_X + PLAYER_SIZE > obstacle_x[k * 10 +: 10]) &&
                (player_y < obstacle_y[k * 9 +: 9] + 9'd40) &&
                (player_y + PLAYER_SIZE > obstacle_y[k * 9 +: 9])
            ) begin
                crash <= 2'b11;
              end
            end
        end
    end

endmodule