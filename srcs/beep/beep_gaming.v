module beep_gaming(
    input wire clk,
    input wire [1:0] gamemode,
    input wire sw,
    input wire [1:0] crash,
    output reg beep
);
    
    reg sw_prev; // 存储上一个时钟周期的sw值
    reg [1:0] crash_prev; // 存储上一个时钟周期的crash值
    reg rst;
    reg [23:0] note_cnt; // 单个音符时间计数器
    reg [19:0] freq_cnt; // 频率计数器
    reg [19:0] freq_data; // 当前频率数据
    wire [19:0] duty_data; // 占空比
    reg sound_active; // 声音激活标志
    reg [3:0] note_index; // 当前播放的音符索引（扩展到4位以支持更多音符）
    reg [3:0] total_notes; // 总音符数量
    reg [1:0] sound_type; // 音效类型：00=上移, 01=下移, 10=碰撞
    
    // 参数定义 - 像素风游戏音效
    parameter MOVE_NOTE_DURATION = 24'd2500000,  // 25ms每个音符 (移动音效)
              CRASH_NOTE_DURATION = 24'd10000000, // 100ms每个音符 (碰撞音效，更慢更沉重)
              // 移动音效音符频率定义
              C5 = 19'd190835,   // 523Hz
              E5 = 19'd151745,   // 659Hz  
              G5 = 19'd127551,   // 784Hz
              C6 = 19'd95420,    // 1047Hz
              // 下移音效音符
              G4 = 19'd255102,   // 392Hz
              E4 = 19'd303030,   // 330Hz
              C4 = 19'd381679,   // 262Hz
              A3 = 19'd454545,   // 220Hz
              // 碰撞音效音符 - 失落感的下降旋律
              F4 = 19'd286532,   // 349Hz
              D4 = 19'd340137,   // 294Hz
              AS3 = 19'd408163,  // 245Hz (降B)
              G3 = 20'd510204,   // 196Hz
              F3 = 20'd573065,   // 175Hz
              D3 = 20'd680272,   // 147Hz
              AS2 = 20'd816327,  // 122Hz
              G2 = 20'd1020408,  // 98Hz
              F2 = 19'd1146129,  // 87Hz
              D2 = 19'd1360544;  // 73Hz
    
    assign duty_data = freq_data >> 1'b1; // 50%占空比
    
    initial begin
        sw_prev = 1'b0;
        crash_prev = 2'b00;
        rst = 1'b0;
        note_cnt = 24'd0;
        freq_cnt = 20'd0;
        freq_data = 20'd0;
        beep = 1'b0;
        sound_active = 1'b0;
        note_index = 4'd0;
        total_notes = 4'd0;
        sound_type = 2'b00;
        current_duration = 24'd0;
    end
    
    // 复位控制逻辑
    always @(*) begin
        if (gamemode == 2'b01) begin
            rst = 1'b0; // 游戏进行中，允许音效
        end else begin
            rst = 1'b1; // 非游戏状态，禁用音效
        end
    end
    
    reg [23:0] current_duration; // 当前音符持续时间
    
    // 根据音效类型设置音符持续时间
    always @(*) begin
        if (sound_type == 2'b10) begin
            current_duration = CRASH_NOTE_DURATION;
        end else begin
            current_duration = MOVE_NOTE_DURATION;
        end
    end
    
    // 检测信号变化并控制音符播放
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_prev <= 1'b0;
            crash_prev <= 2'b00;
            sound_active <= 1'b0;
            note_cnt <= 24'd0;
            note_index <= 4'd0;
            total_notes <= 4'd0;
            sound_type <= 2'b00;
        end else begin
            sw_prev <= sw;
            crash_prev <= crash;
            
            // 优先检测碰撞信号
            if (crash == 2'b11 && crash_prev != 2'b11) begin
                // 碰撞发生，播放失落音效
                sound_active <= 1'b1;
                note_cnt <= 24'd0;
                note_index <= 4'd0;
                sound_type <= 2'b10; // 碰撞音效
                total_notes <= 4'd10; // 10个音符，总共1秒
            end
            // 只有在没有碰撞音效播放时才响应玩家操作
            else if (crash == 2'b00 && sw != sw_prev && !sound_active) begin
                sound_active <= 1'b1;
                note_cnt <= 24'd0;
                note_index <= 4'd0;
                
                if (sw) begin
                    // 上移音效
                    sound_type <= 2'b00;
                    total_notes <= 4'd4;
                end else begin
                    // 下移音效
                    sound_type <= 2'b01;
                    total_notes <= 4'd4;
                end
            end
            
            // 音符时间控制和切换
            else if (sound_active) begin
                if (note_cnt >= current_duration) begin
                    note_cnt <= 24'd0;
                    if (note_index >= total_notes - 1) begin
                        // 所有音符播放完毕
                        sound_active <= 1'b0;
                        note_index <= 4'd0;
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
    
    // 根据当前音符索引和音效类型选择频率
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            freq_data <= 20'd0;
        end else if (sound_active) begin
            case (sound_type)
                2'b00: begin // 上移音效：音调递增
                    case (note_index)
                        4'd0: freq_data <= C5;  // 523Hz
                        4'd1: freq_data <= E5;  // 659Hz
                        4'd2: freq_data <= G5;  // 784Hz
                        4'd3: freq_data <= C6;  // 1047Hz
                        default: freq_data <= C5;
                    endcase
                end
                2'b01: begin // 下移音效：音调递减
                    case (note_index)
                        4'd0: freq_data <= G4;  // 392Hz
                        4'd1: freq_data <= E4;  // 330Hz
                        4'd2: freq_data <= C4;  // 262Hz
                        4'd3: freq_data <= A3;  // 220Hz
                        default: freq_data <= G4;
                    endcase
                end
                2'b10: begin // 碰撞音效：失落感的长旋律（1秒钟，10个音符）
                    case (note_index)
                        4'd0: freq_data <= F4;   // 349Hz - 开始较高
                        4'd1: freq_data <= D4;   // 294Hz
                        4'd2: freq_data <= AS3;  // 245Hz - 降B，增加忧郁感
                        4'd3: freq_data <= G3;   // 196Hz
                        4'd4: freq_data <= F3;   // 175Hz
                        4'd5: freq_data <= D3;   // 147Hz
                        4'd6: freq_data <= AS2;  // 122Hz - 继续下降
                        4'd7: freq_data <= G2;   // 98Hz
                        4'd8: freq_data <= G2;   // 87Hz
                        4'd9: freq_data <= G2;   // 73Hz - 最低点，营造失败感
                        default: freq_data <= F4;
                    endcase
                end
                default: freq_data <= 20'd0;
            endcase
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