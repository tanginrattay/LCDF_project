module game_logic(
    input wire rst_n,
    input wire clk,
    input wire [2:0] btn,         // btn[0]: switch direction, btn[1]: start/pause, btn[2]: end/reset
    input wire [199:0] obstacle_x, // Obstacle x coordinates (10 obstacles, 20 bits each)
    input wire [179:0] obstacle_y, // Obstacle y coordinates (10 obstacles, 18 bits each)
    output reg [1:0] gamemode,    // Game mode: 00=initial, 01=in-game, 10=paused, 11=ended
    output reg [8:0] player_y     // Player y coordinate
);

    parameter UPER_BOUND = 120;
    parameter LOWER_BOUND = 360;
    parameter PLAYER_SIZE = 40;
    parameter ACCELERATION = 1;  
    parameter MAX_VELOCITY = 8;
    parameter PLAYER_X = 160; // Player X coordinate is fixed

    // State registers
    reg signed [9:0] velocity;    // Current velocity (signed, supports positive/negative direction)
    reg direction;                 // 0: down, 1: up
    reg collision;                 // 0: no collision, 1: collision
    reg [9:0] collision_flags;     // Collision flag for each obstacle

    // Edge detection registers
    reg btn0_prev;                 // For btn[0] edge detection
    reg btn1_prev;                 // For btn[1] edge detection
    reg btn2_prev;                 // For btn[2] edge detection
    reg btn0_posedge;
    reg btn1_posedge;
    reg btn2_posedge;

    // Auxiliary and temporary variables
    integer k;
    reg [9:0] obs_x_left;  
    reg [9:0] obs_x_right;   
    reg [8:0] obs_y_top;       
    reg [8:0] obs_y_bottom;

    // Next state registers (calculated in combinatorial logic)
    reg [8:0] next_player_y;
    reg signed [9:0] next_velocity;
    reg next_direction;
    reg next_collision_flags_comb[9:0]; // Combinatorial logic calculated collision flags array
    reg next_collision_comb;            // Combinatorial logic calculated total collision status

    reg signed [9:0] temp_velocity;
    
    
    // Combinatorial logic block: calculate next state and collision detection
    always @(*) begin
        // By default, next state remains current state (unless overridden by subsequent logic)
        next_player_y = player_y;
        next_velocity = velocity;
        next_direction = direction;
        next_collision_comb = 1'b0; // Default to no collision
        
        // Initialize combinatorial collision flags array
        for (k = 0; k < 10; k = k + 1) begin
            next_collision_flags_comb[k] = 1'b0;
        end

        // Collision detection: This is purely combinatorial logic, calculated in real-time
        for (k = 0; k < 10; k = k + 1) begin
            obs_x_left   = obstacle_x[k*20 +: 10];
            obs_x_right  = obstacle_x[k*20+10 +: 10];
            obs_y_top    = obstacle_y[k*18 +: 9];
            obs_y_bottom = obstacle_y[k*18+9 +: 9];

            // Check if obstacle is valid (assuming valid obstacles' x_left/y_top won't equal x_right/y_bottom)
            if (!(obs_x_left == obs_x_right && obs_y_top == obs_y_bottom)) begin 
                // Check for overlap in x and y directions
                if (PLAYER_X <= obs_x_right && (PLAYER_X + PLAYER_SIZE) >= obs_x_left &&
                    player_y <= obs_y_bottom && (player_y + PLAYER_SIZE) >= obs_y_top) begin
                    next_collision_flags_comb[k] = 1'b1;
                    next_collision_comb = 1'b1; // If any obstacle collides, total collision is true
                end
            end
        end

        // Player physics calculation (only valid when game is in progress, but calculated here for combinatorial logic completeness)
        // Actual loading into registers will be restricted by gamemode

        // Temporary velocity variable, used to calculate next position
        
        
        // Logic to handle direction switching. If button is pressed, prioritize direction switch and reset velocity.
        // Note: btn0_posedge is the edge detection result from sequential logic, considered as an input here.
        if (btn0_posedge) begin 
            temp_velocity = 0; // Velocity resets to zero when changing direction
            next_direction = ~direction; // Switch direction
        end else begin
            // Otherwise, update velocity based on current direction
            if (direction) begin // Upward
                if (velocity < MAX_VELOCITY) begin
                    temp_velocity = velocity + ACCELERATION;
                end else begin
                    temp_velocity = MAX_VELOCITY;
                end
            end else begin // Downward
                if (velocity > -MAX_VELOCITY) begin
                    temp_velocity = velocity - ACCELERATION;
                end else begin
                    temp_velocity = -MAX_VELOCITY;
                end
            end
            next_direction = direction; // Direction remains unchanged
        end
        
        next_velocity = temp_velocity; // Assign the calculated velocity to next_velocity

        // Calculate next position
        next_player_y = player_y - next_velocity; // Use the new velocity to calculate the next position

        // Boundary check (done in combinatorial logic)
        if (next_player_y < UPER_BOUND) begin
            next_player_y = UPER_BOUND;
            next_velocity = 0; // Velocity resets to zero at boundary
        end else if (next_player_y > LOWER_BOUND - PLAYER_SIZE) begin
            next_player_y = LOWER_BOUND - PLAYER_SIZE;
            next_velocity = 0; // Velocity resets to zero at boundary
        end
    end


    // Main game logic (sequential logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gamemode <= 2'b00;
            player_y <= (LOWER_BOUND + UPER_BOUND) / 2;
            velocity <= 0;
            direction <= 0;
            btn0_prev <= 1'b0;
            btn1_prev <= 1'b0;
            btn2_prev <= 1'b0;
            collision <= 1'b0;
            collision_flags <= 10'b0;
        end else begin
            // Edge detection (first update button history, then calculate rising edge)
            btn0_posedge = btn[0] && !btn0_prev;
            btn1_posedge = btn[1] && !btn1_prev;
            btn2_posedge = btn[2] && !btn2_prev;

            btn0_prev <= btn[0];
            btn1_prev <= btn[1];
            btn2_prev <= btn[2];
            
            // Update collision status (based on next_collision_comb calculated in combinatorial logic)
            collision <= next_collision_comb;
            // Assigning collision_flags array requires a loop, or use vector assignment (if `next_collision_flags_comb` is defined as a vector)
            // Since `next_collision_flags_comb` is defined as an array, a loop is needed for assignment
            for (k = 0; k < 10; k = k + 1) begin
                collision_flags[k] <= next_collision_flags_comb[k];
            end


            case (gamemode)
                2'b00: begin // Initial state
                    if (btn1_posedge) begin
                        gamemode <= 2'b01;
                        // Reset game state
                        player_y <= (LOWER_BOUND + UPER_BOUND) / 2;
                        velocity <= 0;
                        direction <= 0;
                    end
                end
                2'b01: begin // Game in progress
                    if (btn1_posedge) begin
                        gamemode <= 2'b10; // Pause
                    end else if (btn2_posedge || collision) begin // Collision leads to game over
                        gamemode <= 2'b11; // End game
                    end else begin
                        // Only update player physics when game is in progress
                        player_y <= next_player_y;
                        velocity <= next_velocity;
                        direction <= next_direction;
                    end
                end
                2'b10: begin // Paused
                    if (btn1_posedge) gamemode <= 2'b01; // Resume game
                    if (btn2_posedge) gamemode <= 2'b11; // End game
                end
                2'b11: begin // Ended
                    if (btn2_posedge) gamemode <= 2'b00; // Reset to initial state
                end
                default: gamemode <= 2'b00;
            endcase
        end
    end

endmodule