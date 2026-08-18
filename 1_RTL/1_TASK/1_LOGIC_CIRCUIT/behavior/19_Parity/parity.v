`timescale 1ns / 1ps
module parity(

i_data_in,
o_parity_bit

);

input [7:0] i_data_in;
output o_parity_bit;

assign o_parity_bit = i_data_in[7]^i_data_in[6]^i_data_in[5]^i_data_in[4]^i_data_in[3]^i_data_in[2]^i_data_in[1]^i_data_in[0];
endmodule

module parity_checker(

i_data_in,
i_parity_bit,
o_parity_error

);

input [7:0] i_data_in;
input i_parity_bit;
output o_parity_error;

assign o_parity_error = (^(i_data_in)^i_parity_bit);

endmodule







