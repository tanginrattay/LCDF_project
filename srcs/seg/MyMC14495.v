`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/24 14:45:29
// Design Name: 
// Module Name: MyMC14495
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


module MyMC14495(
  input D0, D1, D2, D3,
  input LE,
  input point,
  output wire p,
  output wire a, b, c, d, e, f, g
);
    // Your code here
    assign p = ~point;
    assign a = ((~D3 & ~D2 & ~D1 & D0) | (D3 & ~D2 & D1 & D0) | (~D3 & D2 & ~D1 & ~D0) | (D3 & D2 & ~D1 & D0)) | LE;
    assign b = ((~D3 & D2 & ~D1 & D0) | (D2 & D1 & ~D0) | (D3 & D2 & ~D0) | (D3 & D1 & D0)) | LE;
    assign c = ((~D3 & ~D2 & D1 & ~ D0) | (D3 & D2 & ~D0) | (D3 & D2 & D1)) | LE;
    assign d = ((~D3 & ~D2 & ~D1 & D0) | (~D3 & D2 & ~D1 & ~D0) | (D2 & D1 & D0) | (D3 & ~D2 & D1 & ~D0)) | LE;
    assign e = ((~D3 & D0) | (~D3 & D2 & ~D1) | (~D2 & ~D1 & D0)) | LE;
    assign f = ((~D3 & ~D2 & D0) | (~D3 & ~D2 & D1) | (D3 & D2 & ~D1 & D0) | (~D3 & D1 & D0)) | LE;
    assign g = ((~D3 & ~D2 & ~D1) | (~D3 & D2 & D1 & D0) | (D3 & D2 & ~D1 & ~D0)) | LE;
endmodule

