module top_beep(
    input wire clk,
    input [1:0] gamemode,
    output reg beep
);
    wire beep_start;
    wire beep_over;

    initial begin
        beep = 1'b0;
    end

    beep_gamestart bp_gs(.clk(clk), .gememode(gememode), .beep(beep_start)); // 调用两个模块
    beep_gameover bp_go(.clk(clk), .gememode(gememode), .beep(beep_over));

    always @(posedge clk) begin
        if (gememode == 2'b00) begin
            beep = beep_start; // 游戏待开始状态，beep 为 game_start 
        end 
        else if (gememode == 2'b11) begin
            beep = beep_over; // 游戏结束状态，beep 为 game_over
        end
    end


endmodule