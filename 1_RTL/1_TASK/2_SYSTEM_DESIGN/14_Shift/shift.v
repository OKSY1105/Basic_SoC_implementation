`timescale 1ns / 1ps

module shift(

i_clk,
i_input,
i_load,
o_out
);

input i_clk, i_load;
input [3:0] i_input;
output o_out;
reg [3:0] o_out;

always @( posedge i_clk) begin
	if(i_load) o_out <= i_input;
	else o_out <= o_out >> 1;
end

endmodule
