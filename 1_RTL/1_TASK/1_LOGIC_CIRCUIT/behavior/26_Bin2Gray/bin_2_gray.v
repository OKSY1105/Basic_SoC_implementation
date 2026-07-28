`timescale 1ns / 1ps
module bin_2_gray(

i_binary_in,
o_gray_out


);

input [3:0] i_binary_in;
output [3:0] o_gray_out;

assign o_gray_out[0] = i_binary_in[0] ^ i_binary_in[1];
assign o_gray_out[1] = i_binary_in[1] ^ i_binary_in[2];
assign o_gray_out[2] = i_binary_in[2] ^ i_binary_in[3];
assign o_gray_out[3] = i_binary_in[3];





endmodule
