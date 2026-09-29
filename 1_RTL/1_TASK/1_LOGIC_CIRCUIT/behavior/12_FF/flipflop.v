`timescale 1ns / 1ps
module flipflop(
i_clk,
i_reset,
i_in,
o_out


);

input i_clk;
input i_reset;
input i_in;
output o_out;

reg o_out;

always @(posedge i_clk or posedge i_reset) begin
	if(i_reset) o_out <=0;
	else o_out<= i_in;


end


endmodule

