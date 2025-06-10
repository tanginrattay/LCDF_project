module beep_gameover(
    input wire clk,          // 输入时钟信号
    input wire [1:0] gamemode, // 游戏状态变量
    output reg beep         // 输出蜂鸣器信号
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
        if (gamemode == 2'b11) begin // 游戏结束页面
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

always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_125ms <= 6'd0;
        end else if (cnt == TIME_125ms && cnt_125ms <= 6'd33) begin
            cnt_125ms <= cnt_125ms + 1'b1;
        end // 当音乐播放结束后，不再重置为 0，实现只播放一次
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
            freq_data <= 18'd0;
        end else begin
            case (cnt_125ms)
        6'd0: freq_data <= C4;
        6'd1: freq_data <= D4;
        6'd2: freq_data <= E4;
                default: freq_data <= C4;
            endcase
        end
    end

endmodule