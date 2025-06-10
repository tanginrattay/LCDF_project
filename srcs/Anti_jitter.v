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

//防抖动
//clk:时钟信号
//BTN:开关状态




module pbdebounce(
	input wire clk_1ms,
	input wire button, 
	output reg pbreg
	);
 
	reg [7:0] pbshift;

	always@(posedge clk_1ms) begin
		pbshift=pbshift<<1;
		pbshift[0]=button;
		if (pbshift==8'b0)
			pbreg=0;
		if (pbshift==8'hFF)
			pbreg=1;	
	end
endmodule



module Anti_jitter(
	input wire clk,
	input wire BTN, 
	output wire BTN_OK
);

wire [31:0] div_res;
clkdiv c1(clk,1'b0,div_res);
pbdebounce p1(div_res[16],BTN,BTN_OK);

//clk_1ms：输入信号为1ms的时钟变化
//button: 不稳定的开关状态
//pbreg： 将开关状态稳定地输出

endmodule
