module top_beep(
    input wire clk,
    input [1:0] gamemode,
    input wire sw,
    output reg beep
);
    wire beep_start;
    wire beep_over;
    wire beep_player;

    initial begin
        beep = 1'b0;
    end

    beep_gamestart bp_gs(.clk(clk), .gamemode(gamemode), .beep(beep_start)); 
    beep_gameover bp_go(.clk(clk), .gamemode(gamemode), .beep(beep_over));
    beep_gaming bp_gi(.clk(clk), .gamemode(gamemode), .sw(sw), .beep(beep_player)); // 修正：添加了缺失的点号

    always @(posedge clk) begin
        if (gamemode == 2'b00) begin
            beep = beep_start; // 游戏待开始状态，beep 为 game_start 
        end 
        else if (gamemode == 2'b11) begin
            beep = beep_over; // 游戏结束状态，beep 为 game_over
        end
        else if (gamemode == 2'b01) begin
            beep = beep_player; // 游戏进行状态，beep 为 player 操作反馈
        end
        else begin
            beep = 1'b0; // 其他状态静音
        end
    end
endmodule