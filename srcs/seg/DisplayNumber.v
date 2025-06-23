`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/31 16:38:59
// Design Name: 
// Module Name: DisplayNumber
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

module DisplayNumber(input clk, RST, input [15:0] Hexs, input [3:0] Points
                , input LES, output wire [7:0] Segment, output wire [3:0] AN);
wire [31:0] div_res; wire [3:0] HEX;
clkdiv c1(clk, RST, div_res);
DisplaySync d1(Hexs, div_res[18:17], Points, LES, HEX, AN, P, LE); 
MyMC14495 M1(.D0(HEX[0]), .D1(HEX[1]), .D2(HEX[2]), .D3(HEX[3]), .LE(LE), .point(P), 
                        .p(p), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g));
assign Segment = {p, g, f, e, d, c, b, a};
endmodule
