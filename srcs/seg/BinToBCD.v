module BinToBCD(
    input  wire [13:0] bin,    // 14-bit binary input
    output reg  [3:0]  bcd3,   // 千位
    output reg  [3:0]  bcd2,   // 百位
    output reg  [3:0]  bcd1,   // 十位
    output reg  [3:0]  bcd0    // 个位
);

    reg [13:0] temp;
    
    always @(*) begin
        temp = bin;
        
        // 直接除法实现（综合工具会优化）
        bcd3 = temp / 1000;
        temp = temp % 1000;
        
        bcd2 = temp / 100;
        temp = temp % 100;
        
        bcd1 = temp / 10;
        bcd0 = temp % 10;
    end
    
endmodule

// 时序版本（如果需要在时钟边沿更新）
module BinToBCD_Clocked(
    input  wire        clk,
    input  wire        rst,
    input  wire [13:0] bin,
    output reg  [3:0]  bcd3,
    output reg  [3:0]  bcd2,
    output reg  [3:0]  bcd1,
    output reg  [3:0]  bcd0
);

    reg [13:0] temp;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bcd3 <= 4'd0;
            bcd2 <= 4'd0;
            bcd1 <= 4'd0;
            bcd0 <= 4'd0;
        end else begin
            temp = bin;
            
            bcd3 <= temp / 1000;
            temp = temp % 1000;
            
            bcd2 <= temp / 100;
            temp = temp % 100;
            
            bcd1 <= temp / 10;
            bcd0 <= temp % 10;
        end
    end
    
endmodule