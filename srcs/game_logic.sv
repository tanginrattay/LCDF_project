module game_logic(
    input wire rst_n,
    input wire clk, // 60Hz frame clock
    input [2:0] sw,
    input logic [9:0] [19:0] obstacle_x,
    input logic [9:0] [17:0] obstacle_y,
    output reg [1:0] gamemode, // �޸�Ϊreg�����Ա���always���и�ֵ
    output reg [8:0] player_y
);

    wire sw_n = ~sw[0]; // Player control switch
    reg [8:0] velocity;
    reg [1:0] crash; // crash״̬
    reg velocity_direction; // 0 for up, 1 for down
    
    // Game constants
    parameter UPPER_BOUND   = 20;
    parameter LOWER_BOUND   = 460;
    parameter PLAYER_SIZE   = 40;
    parameter PLAYER_X_LEFT = 160;
    parameter PLAYER_X_RIGHT= 200; // PLAYER_X_LEFT + PLAYER_SIZE
    parameter MAX_VELOCITY  = 10;
    parameter ACCELERATION  = 1;

    // gamemode�߼���crash״̬���ȼ����
    always_comb begin
        if (crash == 2'b11) begin
            gamemode = 2'b11; // ����״̬���ȼ����
        end else begin
            gamemode = sw[2:1]; // ��������¸��濪��
        end
    end

    // --- Combinational Logic for next state calculation ---
    wire [8:0] velocity_next;
    wire velocity_direction_next;
    wire [8:0] player_y_next;

    // Velocity and direction logic - ֻ��gamemode 01ʱ����
    assign velocity_next = (gamemode == 2'b01) ? (
        (sw_n == velocity_direction) ? 
            ((velocity + ACCELERATION > MAX_VELOCITY) ? MAX_VELOCITY : velocity + ACCELERATION) :
            ((velocity < ACCELERATION) ? (ACCELERATION - velocity) : velocity - ACCELERATION)
    ) : velocity; // ����״̬���ֵ�ǰ�ٶ�

    assign velocity_direction_next = (gamemode == 2'b01) ? (
        (sw_n == velocity_direction) ? velocity_direction :
            ((velocity < ACCELERATION) ? ~velocity_direction : velocity_direction)
    ) : velocity_direction; // ����״̬���ֵ�ǰ����

    // Player position logic - ֻ��gamemode 01ʱ����
    wire [8:0] player_y_calc = velocity_direction_next ? player_y + velocity_next : player_y - velocity_next;

    assign player_y_next = (gamemode == 2'b01) ? (
        (player_y_calc < UPPER_BOUND) ? UPPER_BOUND :
        (player_y_calc > LOWER_BOUND - PLAYER_SIZE) ? (LOWER_BOUND - PLAYER_SIZE) :
        player_y_calc
    ) : player_y; // ����״̬���ֵ�ǰλ��

    // --- Sequential Logic (State Update) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2; // Center the player
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
        end else if (sw[2:1] == 2'b00) begin // �����ػص���ʼ״̬ʱ������Ϸ
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2;
            velocity           <= 0;
            crash              <= 2'b00; // ���crash״̬���������¿�ʼ
            velocity_direction <= 0;
        end else if (crash != 2'b11) begin // ֻ���ڷǱ���״̬�²Ÿ�����Ϸ�߼�
            player_y           <= player_y_next;
            velocity           <= velocity_next;
            velocity_direction <= velocity_direction_next;

            // Collision detection logic - ֻ��gamemode 01ʱ����
            if (gamemode == 2'b01) begin
                crash <= 2'b00; // ���迪ʼʱû����ײ
                for (integer k = 0; k < 10; k = k + 1) begin
                    logic [9:0] obs_x_left   = obstacle_x[k][19:10];
                    logic [9:0] obs_x_right  = obstacle_x[k][9:0];
                    logic [8:0] obs_y_top    = obstacle_y[k][17:9];
                    logic [8:0] obs_y_bottom = obstacle_y[k][8:0];

                    // AABB collision detection algorithm
                    if ( (PLAYER_X_RIGHT > obs_x_left) &&
                         (PLAYER_X_LEFT < obs_x_right) &&
                         (player_y + PLAYER_SIZE > obs_y_top) &&
                         (player_y < obs_y_bottom) ) 
                    begin
                        crash <= 2'b11; // ���ñ���״̬
                    end
                end
            end
            // ��gamemode 10ʱ������crash��⣬���ֵ�ǰcrash״̬
        end
        // ��crash״̬�£����ֵ�ǰ״̬���䣬ֱ������
    end

endmodule