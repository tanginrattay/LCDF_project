// File: map.sv
// Description: Enhanced obstacle map module - improved obstacle removal logic
// Main improvements:
// 1. Uses enhanced random number and difficulty zones
// 2. Enforces Y-axis full coverage algorithm, especially for boundary obstacles
// 3. Dynamic boundary bias to prevent full coverage in the middle
// 4. Tracks boundary obstacle generation ratio, about 40% obstacles are at boundaries
// 5. Improved obstacle removal logic to prevent missing obstacles

module map(
    input wire rst_n,
    input wire clk, // Input clock (60Hz frame clock)
    input wire [1:0] gamemode,
    output wire [13:0] score,
    output logic [9:0] [1:0] obstacle_class,
    output logic [9:0] [9:0] obstacle_x_left,
    output logic [2:0] [9:0] obstacle_x_length,
    output logic [9:0] [8:0] obstacle_y_up,
    output logic [3:0] [8:0] obstacle_y_length
);

//================================================================
// Parameters Definition
//================================================================
localparam NUM_OBSTACLES    = 10;
localparam SCREEN_WIDTH     = 640;
localparam UPPER_BOUND      = 20;
localparam LOWER_BOUND      = 460;
localparam PLAY_AREA_HEIGHT = LOWER_BOUND - UPPER_BOUND;

// Obstacle Parameters
localparam UNIT_LENGTH = 16;
localparam SCROLL_SPEED       = 4;
localparam MIN_OBSTACLE_WIDTH = 20;
localparam MAX_OBSTACLE_WIDTH = 80;
localparam MIN_OBSTACLE_HEIGHT = 20;
localparam MAX_OBSTACLE_HEIGHT = 150;

localparam MIN_GAP_DIFFICULTY = 80;
localparam MAX_GAP_DIFFICULTY = 180;

localparam PLAYER_SIZE_Y      = 40;

// Boundary bias parameters
localparam BOUNDARY_PREFERENCE_THRESHOLD = 8'd102;  // 40% probability to select boundary (102/255 ≈ 40%)
localparam UPPER_BOUNDARY_ZONE_SIZE = 60;           // Upper boundary zone size
localparam LOWER_BOUNDARY_ZONE_SIZE = 60;           // Lower boundary zone size

// Obstacle removal boundary - ensures obstacle is fully off screen before removal
localparam DELETE_BOUNDARY = -100;  // Removal boundary, ensures obstacle is fully off screen

//================================================================
// Internal Signal Definitions
//================================================================
reg [NUM_OBSTACLES-1:0] active;
// Use signed X position to prevent overflow
reg signed [11:0] pos_x [0:NUM_OBSTACLES-1];  // 12-bit signed X position, range -2048 to 2047
reg [8:0]  pos_y [0:NUM_OBSTACLES-1];
reg [6:0]  width [0:NUM_OBSTACLES-1];
reg [7:0]  height [0:NUM_OBSTACLES-1];

reg signed [11:0] next_spawn_x;  // Next spawn X position
reg [1:0] gamemode_prev;

// Registered outputs
reg [9:0] [9:0] obstacle_x_left_reg;
reg [9:0] [9:0] obstacle_x_right_reg;
reg [9:0] [8:0] obstacle_y_up_reg;
reg [9:0] [8:0] obstacle_y_down_reg;

// Score register
reg [13:0] score_reg; // 14 bits, enough for 0~9999

//================================================================
// Enhanced random system
//================================================================

// Random number generators
reg [31:0] rng1, rng2, rng3;
reg [23:0] rng4;
reg [15:0] chaos_counter;      // Chaos counter
reg [31:0] feedback_shift;     // Feedback shift register
reg [7:0]  noise_accumulator;  // Noise accumulator

// Forced coverage mechanism
reg [4:0] coverage_counter;    // Coverage counter (0-31)
reg [7:0] force_coverage_map;  // Forced coverage map
reg [2:0] last_zone;           // Last generated zone

// Boundary generation statistics
reg [7:0] boundary_generation_count;  // Boundary obstacle generation count
reg [7:0] total_generation_count;     // Total obstacle generation count

// Initialization and random update logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Use different initial values
        rng1 <= 32'h12345678;
        rng2 <= 32'h9ABCDEF0;
        rng3 <= 32'hFEDCBA98;
        rng4 <= 24'h123456;
        chaos_counter <= 16'h5A5A;
        feedback_shift <= 32'hA5A5A5A5;
        noise_accumulator <= 8'h33;
        coverage_counter <= 5'b0;
        force_coverage_map <= 8'b0;
        last_zone <= 3'b0;
        boundary_generation_count <= 8'b0;
        total_generation_count <= 8'b0;
    end else begin
        // Update LFSRs with different feedback polynomials
        rng1 <= {rng1[30:0], rng1[31] ^ rng1[21] ^ rng1[1] ^ rng1[0]};
        rng2 <= {rng2[30:0], rng2[31] ^ rng2[27] ^ rng2[5] ^ rng2[3]};
        rng3 <= {rng3[30:0], rng3[31] ^ rng3[25] ^ rng3[7] ^ rng3[2]};
        rng4 <= {rng4[22:0], rng4[23] ^ rng4[18] ^ rng4[12] ^ rng4[6]};
        
        // Update chaos counter - can be adjusted
        chaos_counter <= chaos_counter + ((rng1[7:0] & 8'h0F) | 8'h01);
        
        // Update feedback shift register - for extra randomness
        feedback_shift <= {feedback_shift[30:0], 
                          (rng1[15] ^ rng2[7] ^ rng3[23] ^ rng4[11] ^ chaos_counter[3])};
        
        // Update noise accumulator - accumulates changes
        noise_accumulator <= noise_accumulator + rng1[7:0] + rng2[15:8] + 
                           rng3[23:16] + rng4[7:0] + chaos_counter[7:0];
        
        // Update coverage counter
        coverage_counter <= coverage_counter + 1;
    end
end

//================================================================
// Enhanced random helper functions
//================================================================

// Get chaos random - main random source
function automatic [31:0] get_chaos_random;
    input [4:0] counter;
    begin
        // Mix time, position, history, etc.
        get_chaos_random = rng1 ^ rng2 ^ rng3 ^ {rng4, rng4[7:0]} ^ 
                          feedback_shift ^ {noise_accumulator, noise_accumulator, 
                          noise_accumulator, noise_accumulator} ^
                          ({counter, counter, counter, counter, counter, counter, 2'b0} << 
                           (chaos_counter[3:0] % 16)) ^
                          (chaos_counter * 16'hACE1);
    end
endfunction

// Enhanced boundary Y calculation algorithm
function automatic [8:0] get_enhanced_boundary_y;
    input [31:0] chaos_rng;
    input [7:0] obstacle_height;
    input [4:0] counter;
    input [2:0] last_zone_used;
    input [7:0] coverage_map;
    input [7:0] boundary_count;
    input [7:0] total_count;
    
    reg [8:0] max_y_pos;
    reg [8:0] result_y;
    reg [7:0] boundary_preference;
    reg [7:0] boundary_ratio;
    reg use_boundary_generation;
    reg use_upper_boundary;
    reg [8:0] boundary_offset;
    reg [8:0] middle_area_start, middle_area_end;
    
    begin
        max_y_pos = LOWER_BOUND - obstacle_height;
        
        if (max_y_pos <= UPPER_BOUND) begin
            get_enhanced_boundary_y = UPPER_BOUND;
        end else begin
            // Calculate current boundary generation ratio
            if (total_count > 0) begin
                boundary_ratio = (boundary_count * 8'd100) / total_count;
            end else begin
                boundary_ratio = 8'd0;
            end
            
            // Dynamic boundary bias - if boundary ratio is low, increase bias
            if (boundary_ratio < 8'd35) begin // If boundary ratio < 35%
                boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD + 8'd51; // Increase to ~60%
            end else if (boundary_ratio > 8'd50) begin // If boundary ratio > 50%
                boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD - 8'd25; // Decrease to ~30%
            end else begin
                boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD; // Default 40%
            end
            
            // Decide whether to use boundary generation
            use_boundary_generation = (chaos_rng[7:0] < boundary_preference);
            
            // Force boundary coverage if needed
            if (counter[3:0] == 4'b1111) begin
                if (!coverage_map[0] || !coverage_map[7]) begin
                    use_boundary_generation = 1'b1;
                end
            end
            
            if (use_boundary_generation) begin
                // Boundary mode
                use_upper_boundary = chaos_rng[8]; // 50% chance for upper or lower boundary
                
                if (use_upper_boundary) begin
                    // Upper boundary area (UPPER_BOUND to UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE)
                    if (UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE <= max_y_pos) begin
                        boundary_offset = (chaos_rng[23:16] ^ noise_accumulator) % UPPER_BOUNDARY_ZONE_SIZE;
                        result_y = UPPER_BOUND + boundary_offset;
                    end else begin
                        result_y = UPPER_BOUND;
                    end
                end else begin
                    // Lower boundary area (max_y_pos - LOWER_BOUNDARY_ZONE_SIZE to max_y_pos)
                    if (max_y_pos >= LOWER_BOUNDARY_ZONE_SIZE) begin
                        boundary_offset = (chaos_rng[15:8] ^ noise_accumulator) % LOWER_BOUNDARY_ZONE_SIZE;
                        result_y = max_y_pos - boundary_offset;
                        if (result_y < UPPER_BOUND) result_y = UPPER_BOUND;
                    end else begin
                        result_y = max_y_pos;
                    end
                end
            end else begin
                // Middle area mode - not at boundary
                middle_area_start = UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE;
                middle_area_end = max_y_pos - LOWER_BOUNDARY_ZONE_SIZE;
                
                if (middle_area_end > middle_area_start) begin
                    boundary_offset = (chaos_rng[31:24] ^ chaos_rng[15:8] ^ noise_accumulator) % 
                                    (middle_area_end - middle_area_start);
                    result_y = middle_area_start + boundary_offset;
                end else begin
                    // If middle area too small, use full range
                    boundary_offset = (chaos_rng[23:16] ^ noise_accumulator) % (max_y_pos - UPPER_BOUND);
                    result_y = UPPER_BOUND + boundary_offset;
                end
            end
            
            // Clamp to valid range
            if (result_y > max_y_pos) result_y = max_y_pos;
            if (result_y < UPPER_BOUND) result_y = UPPER_BOUND;
            
            get_enhanced_boundary_y = result_y;
        end
    end
endfunction

// Random width generator
function automatic [7:0] get_random_width;
    input [31:0] chaos_rng;
    begin
        get_random_width = MIN_OBSTACLE_WIDTH + 
            ((chaos_rng[7:0] ^ chaos_rng[15:8]) % (MAX_OBSTACLE_WIDTH - MIN_OBSTACLE_WIDTH + 1));
    end
endfunction

// Random height generator
function automatic [7:0] get_random_height;
    input [31:0] chaos_rng;
    begin
        get_random_height = MIN_OBSTACLE_HEIGHT + 
            ((chaos_rng[23:16] ^ chaos_rng[31:24]) % (MAX_OBSTACLE_HEIGHT - MIN_OBSTACLE_HEIGHT + 1));
    end
endfunction

// Random gap generator
function automatic [7:0] get_random_gap;
    input [31:0] chaos_rng;
    begin
        get_random_gap = MIN_GAP_DIFFICULTY + 
            ((chaos_rng[31:24] ^ chaos_rng[7:0]) % (MAX_GAP_DIFFICULTY - MIN_GAP_DIFFICULTY + 1));
    end
endfunction

//================================================================
// Main state machine and obstacle logic
//================================================================
// Disappeared obstacle counter
reg [3:0] disappear_count;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
        gamemode_prev <= 2'b00;
        boundary_generation_count <= 8'b0;
        total_generation_count <= 8'b0;
        score_reg <= 14'd0;
        disappear_count <= 4'd0;  // 初始化计数器
        for (integer i = 0; i < NUM_OBSTACLES; i++) begin
            active[i] <= 1'b0;
            pos_x[i] <= SCREEN_WIDTH + 100;
            pos_y[i] <= UPPER_BOUND;
            width[i] <= MIN_OBSTACLE_WIDTH;
            height[i] <= MIN_OBSTACLE_HEIGHT;
        end
    end else begin
        gamemode_prev <= gamemode;

        if (gamemode == 2'b00) begin
            // Reset state in idle mode
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                active[i] <= 1'b0;
                pos_x[i] <= SCREEN_WIDTH + 100;
            end
            next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
            force_coverage_map <= 8'b0;
            boundary_generation_count <= 8'b0;
            total_generation_count <= 8'b0;
            score_reg <= 14'd0;
            disappear_count <= 4'd0;
        end
        else if (gamemode == 2'b01) begin
            if (gamemode_prev == 2'b00) begin
                for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                    active[i] <= 1'b0;
                    pos_x[i] <= SCREEN_WIDTH + 100;
                end
                next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
                force_coverage_map <= 8'b0;
                boundary_generation_count <= 8'b0;
                total_generation_count <= 8'b0;
                score_reg <= 14'd0;
                disappear_count <= 4'd0;
            end

            // Move all active obstacles
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (active[i]) begin
                    pos_x[i] <= pos_x[i] - SCROLL_SPEED;
                end
            end

            next_spawn_x <= next_spawn_x - SCROLL_SPEED;

            // 重置消失计数器
            disappear_count <= 4'd0;

            // Remove obstacles that are off screen and count them
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (active[i] && (pos_x[i] + $signed({5'b0, width[i]}) < DELETE_BOUNDARY)) begin
                    active[i] <= 1'b0;
                    disappear_count <= disappear_count + 1'b1;
                end
            end

            // Score accumulation in next clock cycle (will be handled by the register update)
            if (score_reg + disappear_count > 14'd9999)
                score_reg <= 14'd9999;
            else
                score_reg <= score_reg + disappear_count;

            // Generate new obstacle if needed
            if (next_spawn_x <= SCREEN_WIDTH) begin
                for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                    if (!active[i]) begin
                        reg [31:0] chaos_random;
                        reg [7:0] new_width, new_height;
                        reg [8:0] new_y_pos;
                        reg [7:0] gap_size;
                        reg [2:0] selected_zone;
                        reg is_boundary_obstacle;

                        // Generate random numbers
                        chaos_random = get_chaos_random(coverage_counter);
                        
                        new_width = get_random_width(chaos_random);
                        new_height = get_random_height(chaos_random);
                        
                        // Use enhanced boundary Y algorithm
                        new_y_pos = get_enhanced_boundary_y(chaos_random, new_height, 
                                                          coverage_counter, last_zone, force_coverage_map,
                                                          boundary_generation_count, total_generation_count);
                        gap_size = get_random_gap(chaos_random);

                        // Check if this is a boundary obstacle
                        is_boundary_obstacle = (new_y_pos <= (UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE)) ||
                                             (new_y_pos >= (LOWER_BOUND - new_height - LOWER_BOUNDARY_ZONE_SIZE));

                        // Update statistics
                        total_generation_count <= total_generation_count + 1;
                        if (is_boundary_obstacle) begin
                            boundary_generation_count <= boundary_generation_count + 1;
                        end
                        
                        // Prevent overflow
                        if (total_generation_count == 8'hFF) begin
                            total_generation_count <= 8'd100;
                            boundary_generation_count <= (boundary_generation_count > 8'd100) ? 
                                                        8'd40 : (boundary_generation_count * 8'd100) / 8'hFF;
                        end

                        // Update coverage map
                        selected_zone = ((new_y_pos - UPPER_BOUND) * 8) / (LOWER_BOUND - UPPER_BOUND - new_height);
                        if (selected_zone <= 7) begin
                            force_coverage_map[selected_zone] <= 1'b1;
                        end
                        last_zone <= selected_zone;

                        // Every 32 obstacles, reset coverage map
                        if (coverage_counter == 5'b11111) begin
                            force_coverage_map <= 8'b0;
                        end

                        active[i] <= 1'b1;
                        pos_x[i] <= SCREEN_WIDTH;
                        pos_y[i] <= new_y_pos;
                        width[i] <= new_width[6:0];
                        height[i] <= new_height;

                        next_spawn_x <= SCREEN_WIDTH + gap_size;
                        break;
                    end
                end
            end
        end
    end
end
//================================================================
// Output logic
//================================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer k = 0; k < NUM_OBSTACLES; k++) begin
            obstacle_x_left_reg[k]  <= 10'd700;
            obstacle_x_right_reg[k] <= 10'd700;
            obstacle_y_up_reg[k]    <= 9'd500;
            obstacle_y_down_reg[k]  <= 9'd500;
        end
    end else begin
        for (integer k = 0; k < NUM_OBSTACLES; k++) begin
            // Only output obstacles that are active and within screen
            if (active[k] && pos_x[k] >= 0 && pos_x[k] < SCREEN_WIDTH) begin
                obstacle_x_left_reg[k]  <= 10'(pos_x[k]);
                obstacle_x_right_reg[k] <= 10'(pos_x[k] + $signed({5'b0, width[k]}));
                obstacle_y_up_reg[k]    <= pos_y[k];
                obstacle_y_down_reg[k]  <= 9'(pos_y[k] + height[k]);
            end else begin
                obstacle_x_left_reg[k]  <= 10'd700;
                obstacle_x_right_reg[k] <= 10'd700;
                obstacle_y_up_reg[k]    <= 9'd500;
                obstacle_y_down_reg[k]  <= 9'd500;
            end
        end
    end
end

assign obstacle_x_left  = obstacle_x_left_reg;
assign obstacle_x_right = obstacle_x_right_reg;
assign obstacle_y_up    = obstacle_y_up_reg;
assign obstacle_y_down  = obstacle_y_down_reg;

// Output score
assign score = score_reg;
assign obstacle_class[0] = 2'b00;
assign obstacle_class[1] = 2'b01; // Example classes, can be extended
assign obstacle_class[2] = 2'b10;
assign obstacle_class[3] = 2'b11;
assign obstacle_class[4] = 2'b00;
assign obstacle_class[5] = 2'b01;
assign obstacle_class[6] = 2'b10;
assign obstacle_class[7] = 2'b11;
assign obstacle_class[8] = 2'b00;
assign obstacle_class[9] = 2'b01; // Example classes, can be extended

endmodule