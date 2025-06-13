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

    beep_gamestart bp_gs(.clk(clk), .gamemode(gamemode), .beep(beep_start)); // 调用两个模块
    beep_gameover bp_go(.clk(clk), .gamemode(gamemode), .beep(beep_over));

    always @(posedge clk) begin
        if (gamemode == 2'b01)
            beep = beep_start;
        else if (gamemode == 2'b11)
            beep = beep_over;
        // 建议加 else 分支，防止beep保持上一次值
        else
            beep = 1'b0;
    end


endmodule