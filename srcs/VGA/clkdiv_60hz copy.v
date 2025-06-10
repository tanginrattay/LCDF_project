module clkdiv_60hz(
    input wire clk,      // 100MHz 输入时钟
    input wire rst_n,    // 低电平有效的复位信号
    output reg clk_60hz  // 约60Hz 的输出时钟
);

    // 定义分频参数
    parameter N = 833333;  // 计数器周期，100MHz / (2 * N) ≈ 60Hz

    // 计数器寄存器，32位宽足够容纳N
    reg [31:0] counter;

    // 时钟分频逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 32'd0;    // 复位时计数器清零
            clk_60hz <= 1'b0;    // 复位时输出时钟为0
        end else begin
            if (counter == N - 1) begin
                counter <= 32'd0;    // 计数器达到N-1时重置
                clk_60hz <= ~clk_60hz;  // 输出时钟翻转
            end else begin
                counter <= counter + 1;  // 计数器递增
            end
        end
    end

endmodule