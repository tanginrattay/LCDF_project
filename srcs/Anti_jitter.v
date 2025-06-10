`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/04 22:46:25
// Design Name: 
// Module Name: Anti_jitter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Anti_jitter(
    input clk,
    input BTN,
    output reg BTN_OK
    );
    
    reg [7:0] count;
    initial begin
        count <= 8'b00000000;
        BTN_OK <= 1'b0;
    end
    always @(posedge clk)begin
        count <= {count[6:0],BTN};
        if(count==8'b11111111)  BTN_OK <= 1'b1;
        else    BTN_OK <= 1'b0;
    end
       
endmodule
