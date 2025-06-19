module map(
    input wire rst_n,               
    input wire clk,                 
    output wire [29:0] obstacle_x, // 30 bits for 3 obstacles (10 bits each) 
    output wire [26:0] obstacle_y   
);

    // Assume the size is 40*40, so we only record the top-left corner of each obstacle
    assign obstacle_x = {10'd160, 10'd230, 10'd300}; 
    assign obstacle_y = {9'd20, 9'd200, 9'd300}; 

endmodule