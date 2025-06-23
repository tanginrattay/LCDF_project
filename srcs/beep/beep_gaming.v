module beep_gaming(
    input wire clk,
    input wire [1:0] gamemode,
    input wire sw,
    output reg beep
);
    
    reg sw_prev; // 存储上一个时钟周期的sw值
    reg rst;
    reg [23:0] note_cnt; // 单个音符时间计数器
    reg [19:0] freq_cnt; // 频率计数器
    reg [19:0] freq_data; // 当前频率数据
    wire [19:0] duty_data; // 占空比
    reg sound_active; // 声音激活标志
    reg [2:0] note_index; // 当前播放的音符索引
    reg [2:0] total_notes; // 总音符数量
    reg is_up_sound; // 是否为上移音效
    
    // 参数定义 - 像素风游戏音效
    parameter NOTE_DURATION = 24'd2500000, // 25ms每个音符 (100MHz时钟)
              // 音符频率定义 (像素风格的8位游戏音效)
              C5 = 19'd190835,   // 523Hz
              E5 = 19'd151745,   // 659Hz  
              G5 = 19'd127551,   // 784Hz
              C6 = 19'd95420,    // 1047Hz
              // 下移音效音符
              G4 = 19'd255102,   // 392Hz
              E4 = 19'd303030,   // 330Hz
              C4 = 19'd381679,   // 262Hz
              A3 = 19'd454545;   // 220Hz
    
    assign duty_data = freq_data >> 1'b1; // 50%占空比
    
    initial begin
        sw_prev = 1'b0;
        rst = 1'b0;
        note_cnt = 24'd0;
        freq_cnt = 20'd0;
        freq_data = 20'd0;
        beep = 1'b0;
        sound_active = 1'b0;
        note_index = 3'd0;
        total_notes = 3'd0;
        is_up_sound = 1'b0;
    end
    
    // 复位控制逻辑
    always @(*) begin
        if (gamemode == 2'b01) begin
            rst = 1'b0; // 游戏进行中，允许音效
        end else begin
            rst = 1'b1; // 非游戏状态，禁用音效
        end
    end
    
    // 检测sw信号的边沿变化并控制音符播放
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_prev <= 1'b0;
            sound_active <= 1'b0;
            note_cnt <= 24'd0;
            note_index <= 3'd0;
            total_notes <= 3'd0;
            is_up_sound <= 1'b0;
        end else begin
            sw_prev <= sw;
            
            // 检测到sw变化时启动音效序列
            if (sw != sw_prev && !sound_active) begin // 防止正在播放时被打断
                sound_active <= 1'b1;
                note_cnt <= 24'd0;
                note_index <= 3'd0;
                
                if (sw) begin
                    // 上移音效：快速上升的4个音符 (C5-E5-G5-C6)
                    is_up_sound <= 1'b1;
                    total_notes <= 3'd4;
                end else begin
                    // 下移音效：快速下降的4个音符 (G4-E4-C4-A3)
                    is_up_sound <= 1'b0;
                    total_notes <= 3'd4;
                end
            end
            
            // 音符时间控制和切换
            else if (sound_active) begin
                if (note_cnt >= NOTE_DURATION) begin
                    note_cnt <= 24'd0;
                    if (note_index >= total_notes - 1) begin
                        // 所有音符播放完毕
                        sound_active <= 1'b0;
                        note_index <= 3'd0;
                    end else begin
                        // 切换到下一个音符
                        note_index <= note_index + 1'b1;
                    end
                end else begin
                    note_cnt <= note_cnt + 1'b1;
                end
            end
        end
    end
    
    // 根据当前音符索引选择频率
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            freq_data <= 20'd0;
        end else if (sound_active) begin
            if (is_up_sound) begin
                // 上移音效：音调递增
                case (note_index)
                    3'd0: freq_data <= C5;  // 523Hz
                    3'd1: freq_data <= E5;  // 659Hz
                    3'd2: freq_data <= G5;  // 784Hz
                    3'd3: freq_data <= C6;  // 1047Hz
                    default: freq_data <= C5;
                endcase
            end else begin
                // 下移音效：音调递减
                case (note_index)
                    3'd0: freq_data <= G4;  // 392Hz
                    3'd1: freq_data <= E4;  // 330Hz
                    3'd2: freq_data <= C4;  // 262Hz
                    3'd3: freq_data <= A3;  // 220Hz
                    default: freq_data <= G4;
                endcase
            end
        end else begin
            freq_data <= 20'd0;
        end
    end
    
    // 频率计数器
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            freq_cnt <= 20'd0;
        end else if (sound_active && freq_data != 20'd0) begin
            if (freq_cnt >= freq_data) begin
                freq_cnt <= 20'd0;
            end else begin
                freq_cnt <= freq_cnt + 1'b1;
            end
        end else begin
            freq_cnt <= 20'd0;
        end
    end
    
    // 蜂鸣器输出控制
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            beep <= 1'b0;
        end else if (sound_active && freq_data != 20'd0 && freq_cnt > duty_data) begin
            beep <= 1'b1;
        end else begin
            beep <= 1'b0;
        end
    end
    
endmodule