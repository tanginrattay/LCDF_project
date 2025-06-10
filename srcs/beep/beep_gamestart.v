module beep_gamestart(
    input clk,
    input [1:0] memode, // 游戏状态变量
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
                D5 = 19'd170357, // 587
                C5 = 19'd191204, // 523
                B4 = 19'd202428, // 494
                FS_4 = 19'd270269, // 370
                G4 = 19'd255101, // 392
                D4 = 19'd378787, // 264
                E4 = 19'd303030, // 330
                F4 = 19'd286532, // 349
                C4 = 19'd381678; // 262

    assign duty_data = freq_data >> 1'b1;

always @(gamemode) begin
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
            default: freq_data <= D4;
        endcase
    end
end

endmodule