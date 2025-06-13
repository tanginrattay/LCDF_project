module beep_gamestart(
    input clk,
    input [1:0] gamemode, // 游戏状态变量 (game state variable)
    output reg beep
    );

    reg rst;
    reg [23:0] cnt; // cnt用来计时，记录125ms的时间,这里4/4拍的音乐，每 125ms 产生一个音符
    reg [5:0] cnt_125ms; // 125ms个数计数 (counter for 125ms intervals),用来数经过了几拍

    reg [19:0] freq_cnt; // 音调频率计数 (pitch frequency counter)
    reg [19:0] freq_data; // 音调频率 (pitch frequency data)

    wire [19:0] duty_data; // 占空比 (duty cycle)

    initial begin // 初始化所有 reg 信号 (initialize all reg signals)
        rst = 1'b0;
        beep = 1'b0;
        cnt = 24'b0;
        freq_cnt = 20'b0;
        cnt_125ms = 6'b0;
        freq_data = 20'b0;
    end

    // Parameters for notes based on 60MHz clock
    // (计算公式：计数器值 = 时钟频率 / 音符频率)
    // 请注意：你的 freq_data 是周期计数，即 60MHz / 频率。
    // 以下是我基于这个规则并结合 "Every Breath You Take" 简化旋律提供的音符频率值。
    parameter TIME_125ms = 24'd12499999, // 125 ms (60MHz * 0.125s - 1)

              // Every Breath You Take 主旋律所需音符频率 (Period values for notes)
              A4_freq = 20'd136363, // A4 (440 Hz) -> 60,000,000 / 440 = 136363
              E5_freq = 20'd90909,  // E5 (659 Hz) -> 60,000,000 / 659 = 90909
              F5_freq = 20'd85960,  // F5 (698 Hz) -> 60,000,000 / 698 = 85960
              D5_freq = 20'd102136, // D5 (587 Hz) -> 60,000,000 / 587 = 102136
              C5_freq = 20'd114627, // C5 (523 Hz) -> 60,000,000 / 523 = 114627
              B4_freq = 20'd121457, // B4 (494 Hz) -> 60,000,000 / 494 = 121457
              G4_freq = 20'd153061, // G4 (392 Hz) -> 60,000,000 / 392 = 153061
              F4_freq = 20'd171854, // F4 (349 Hz) -> 60,000,000 / 349 = 171854
              E4_freq = 20'd181818, // E4 (330 Hz) -> 60,000,000 / 330 = 181818
              D4_freq = 20'd227272, // D4 (264 Hz) -> 60,000,000 / 264 = 227272
              REST = 20'd0;         // 静音 (mute), 将频率设为0，则 `beep` 会保持0

    assign duty_data = freq_data >> 1'b1; // 占空比为 50% (50% duty cycle)

    always @(*) begin
        if (gamemode == 2'b00) begin // 游戏开始页面 (game start page)
            rst = 1'b0; // rst 为 0 时，声波正常产生 (when rst is 0, sound wave is generated normally)
        end
        else begin
            rst = 1'b1; // rst 为 1 时，声波不产生 (when rst is 1, no sound wave is generated)
        end
    end

    // cnt用来计时，记录125ms的时间 (cnt is used to time, recording 125ms)
    // 这里4/4拍的音乐，每 125ms 产生一个音符 (here for 4/4 time music, each note is 125ms)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 24'd0;
        end
        else if (cnt == TIME_125ms) begin // 每当 cnt 达到 TIME_125ms 即每过 1 个单位时间，该变量重置为 0 重新开始计数
            cnt <= 24'd0;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end

    // cnt_125ms 用来计数 125ms 的个数 (cnt_125ms is used to count the number of 125ms intervals)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_125ms <= 6'd0;
        end
        // 根据音乐序列长度调整循环重置条件。当前序列有 16 个节拍 (0-15)。
        // Adjust the loop reset condition based on the music sequence length. Current sequence has 16 beats (0-15).
        else if (cnt == TIME_125ms && cnt_125ms == 6'd15) begin // 音乐播放结束时，重置为 0 ，实现循环播放音乐
            cnt_125ms <= 6'd0;
        end
        else if (cnt == TIME_125ms) begin // 每过 1 个时间单位，变量值加 1
            cnt_125ms <= cnt_125ms + 1'b1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            freq_cnt <= 19'd0;
        end
        // 当频率计数信号大于此时的声音频率时，或每当过 1 个板载时钟周期时 (when freq_cnt exceeds freq_data, or every board clock cycle)
        // 注意：这里 `cnt == TIME_125ms` 作为重置条件，可能会导致音符切换时的第一个时钟周期计数不完整。
        // 通常只在 `freq_cnt >= freq_data` 时重置，以确保一个完整的周期。
        // 但如果你的设计需要每 125ms 强制重置，则保持。
        else if (freq_cnt >= freq_data) begin
            freq_cnt <= 19'd0;
        end
        else begin
            freq_cnt <= freq_cnt + 1'b1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            beep <= 1'b0;
        end
        // 当频率计数信号大于占空比时，使 PWM 为 1，实现 50% 的占空比 (when freq_cnt > duty_data, set PWM to 1 for 50% duty cycle)
        else if (freq_data == REST) begin // 如果是静音，则beep保持为0
            beep <= 1'b0;
        end
        else if (freq_cnt > duty_data) begin
            beep <= 1'b1;
        end
        else begin
            beep <= 1'b0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            freq_data <= 19'd0;
        end
        else begin
            // 根据不同的时间段，为该变量赋值不同的频率值 (assign different frequency values based on time intervals)
            // The Police - Every Breath You Take (主吉他旋律简化版)
            // 节拍顺序： A4, E5, F5, E5, D5, C5, B4, A4, REST, G4, F4, E4, D4, REST...
            case (cnt_125ms)
                // 第一小节：主旋律 A4 - E5 - F5 - E5
                6'd0:  freq_data <= A4_freq; // A4
                6'd1:  freq_data <= E5_freq; // E5
                6'd2:  freq_data <= F5_freq; // F5
                6'd3:  freq_data <= E5_freq; // E5

                // 第二小节：主旋律 D5 - C5 - B4 - A4
                6'd4:  freq_data <= D5_freq; // D5
                6'd5:  freq_data <= C5_freq; // C5
                6'd6:  freq_data <= B4_freq; // B4
                6'd7:  freq_data <= A4_freq; // A4

                // 第三小节：衔接旋律 G4 - F4 - E4 - D4
                6'd8:  freq_data <= G4_freq; // G4
                6'd9:  freq_data <= F4_freq; // F4
                6'd10: freq_data <= E4_freq; // E4
                6'd11: freq_data <= D4_freq; // D4

                // 第四小节：短暂静音，准备下一次循环，使音乐更流畅 (short rest, preparing for next loop, making music smoother)
                6'd12: freq_data <= REST;    // 静音 (rest)
                6'd13: freq_data <= REST;    // 静音
                6'd14: freq_data <= REST;    // 静音
                6'd15: freq_data <= REST;    // 静音

                default: freq_data <= REST; // 默认情况下静音，防止意外噪音 (default to rest to prevent unexpected noise)
            endcase
        end
    end

endmodule