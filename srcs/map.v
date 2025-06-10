module map(
    input wire rst_n,                // 低电平有效的复位信号
    input wire clk,                  // 时钟信号
    output wire [199:0] obstacle_x,  // 10个障碍物的X坐标范围，每个20位（左10+右10）
    output wire [179:0] obstacle_y   // 10个障碍物的Y坐标范围，每个18位（上9+下9）
);

    // 直接将所有输出置为0
    assign obstacle_x = 200'd0;
    assign obstacle_y = 180'd0;

endmodule