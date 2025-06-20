module beep_gamestart(
    input clk,
    input [1:0] gamemode, // 游戏状态变量
    output reg beep
    );

    reg rst;
    reg [23:0] cnt; //cnt用来计时，记录125ms的时间,这里4/4拍的音乐，每 125ms 产生一个音符
    reg [5:0] cnt_125ms; // 125ms个数计数,用来数经过了几拍

    reg [19:0] freq_cnt; // 音调频率计数
    reg [19:0] freq_data; // 音调频率

    wire [19:0] duty_data; // 占空比

    initial begin // 初始化所有 reg 信号
        rst = 1'b0;
        beep = 1'b0;
        cnt = 24'b0;
        freq_cnt = 20'b0;
        cnt_125ms = 6'b0;
        freq_data = 20'b0;
    end

    parameter TIME_125ms = 24'd12499999, // 125 ms
                A4 = 19'd227273, // 440 Hz
                A14=19'd214519, // 466.16Hz
                G4 = 19'd255101, // 392Hz
                D4 = 19'd378787, // 264Hz
                E4 = 19'd303030, // 330Hz
                F4 = 19'd286532, // 349Hz
                C4 = 19'd381678; // 262Hz

    assign duty_data = freq_data >> 1'b1;

always @(*) begin
        if (gamemode == 2'b00) begin // 游戏开始页面
            rst = 1'b0; // rst 为 0 时，声波正常产生
        end 
        else begin
            rst = 1'b1; // rst 为 1 时，声波不产生
        end
    end

//cnt用来计时，记录125ms的时间,这里4/4拍的音乐，每 125ms 产生一个音符
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 24'd0;end 
        else if (cnt == TIME_125ms) begin // 每当 cnt 达到 TIME_125ms 即每过 1 个单位时间，该变量重置为 0 重新开始计数
            cnt <= 24'd0;end 
        else begin
            cnt <= cnt + 1'b1;end
    end

// cnt_125ms 用来计数 125ms 的个数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_125ms <= 6'd0;end 
    else if (cnt == TIME_125ms && cnt_125ms == 7'd64) begin // 音乐播放结束时，重置为 0 ，实现循环播放音乐
        cnt_125ms <= 6'd0;end 
    else if (cnt == TIME_125ms) begin // 每过 1 个时间单位，变量值加 1
        cnt_125ms <=    cnt_125ms + 1'b1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        freq_cnt <= 19'd0;end 
    else if (freq_cnt >= freq_data || cnt == TIME_125ms) begin // 当频率计数信号大于此时的声音频率，或每当过 1 个板载时钟周期时，该值重置为 0 
        freq_cnt <= 19'd0;end 
    else begin
        freq_cnt <= freq_cnt + 1'b1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        beep <= 1'b0;
    end else if (freq_cnt > duty_data) begin // 当频率计数信号大于占空比时，使 PWM 为 1，实现 50% 的占空比
        beep <= 1'b1;
    end else begin
        beep <= 1'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        freq_data <= 19'd0;
    end else begin
        case (cnt_125ms) // 根据不同的时间段，为该变量赋值不同的频率值
            7'd0: freq_data <= D4;  
            7'd1: freq_data <= E4;
            7'd2: freq_data <= F4;
            7'd3: freq_data <= G4;
            7'd4: freq_data <= A4;  
            7'd5: freq_data <= A4;
            7'd6: freq_data <= A4;
            7'd7: freq_data <= A4;
            7'd8: freq_data <= D4; 
            7'd9: freq_data <= D4;
            7'd10: freq_data <= D4; 
            7'd11: freq_data <= D4;
            7'd12: freq_data <= G4; 
            7'd13: freq_data <= G4;
            7'd14: freq_data <= G4;  
            7'd15: freq_data <= G4;
            7'd16: freq_data <= C4; 
            7'd17: freq_data <= C4;
            7'd18: freq_data <= F4;  
            7'd19: freq_data <= F4;
            7'd20: freq_data <= F4;
            7'd21: freq_data <= F4;
            7'd22: freq_data <= D4;  
            7'd23: freq_data <= D4;
            7'd24: freq_data <= E4;
            7'd25: freq_data <= E4;
            7'd26: freq_data <= F4;  
            7'd27: freq_data <= F4;
            7'd28: freq_data <= F4;
            7'd29: freq_data <= F4;
            7'd30: freq_data <= G4;  
            7'd31: freq_data <= G4;
            7'd32: freq_data <= A4;
            7'd33: freq_data <= A4;
            7'd34: freq_data <= F4;  
            7'd35: freq_data <= F4;
            7'd36: freq_data <= A14;  
            7'd37: freq_data <= A14;
            7'd38: freq_data <= A14;
            7'd39: freq_data <= A14;
            7'd40: freq_data <= E4;  
            7'd41: freq_data <= E4;
            7'd42: freq_data <= E4;
            7'd43: freq_data <= E4;
            7'd44: freq_data <= A4;  
            7'd45: freq_data <= A4;
            7'd46: freq_data <= A4;
            7'd47: freq_data <= A4;
            7'd48: freq_data <= D4;
            7'd49: freq_data <= D4;
            7'd50: freq_data <= G4;
            7'd51: freq_data <= G4;            
            7'd52: freq_data <= G4;
            7'd53: freq_data <= G4;
            7'd54: freq_data <= G4;
            7'd55: freq_data <= G4;            
            7'd56: freq_data <= G4;
            7'd57: freq_data <= G4;
            default: freq_data <= 19'd0;
        endcase
    end
end

endmodule
