`timescale 1ns/1ps

module pipeline(
input clk, 
input rst_n,
input [9:0] i_in1,
input [9:0] i_in2,
input [9:0] i_in3,
output [11:0] o_out
);
reg [9:0] r_temp0;
reg [10:0] r_temp1;
reg [11:0] o_out;


always @(posedge clk) begin
	if(!rst_n) begin

	r_temp0<=0;
	r_temp1<=0;

        end

	else begin
	r_temp0<=i_in3;
	r_temp1<= i_in1+i_in2;
	o_out <=r_temp1+r_temp0;	

	end

end


endmodule
