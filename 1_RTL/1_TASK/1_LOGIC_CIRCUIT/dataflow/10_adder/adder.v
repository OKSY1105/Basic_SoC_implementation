`timescale 1ns / 1ps



module adder(

i_a,
i_b,
i_cin,
o_sum,
o_cout

);

input [3:0] i_a;
input [3:0] i_b;
input i_cin;
output [3:0] o_sum;
output o_cout;

assign o_sum = i_a^i_b^i_cin;
assign o_cout = (i_a | i_b)& i_cin;

endmodule
