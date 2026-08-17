`timescale 1ns / 1ps
module parity(

data_in,
parity_bit

);

input [7:0] data_in;
output parity_bit;

assign parity_bit = data_in[7]^data_in[6]^data_in[5]^data_in[4]^data_in[3]^data_in[2]^data_in[1]^data_in[0];
endmodule


module parity_checker(

data_in,
parity_bit,
parity_error

);

input [7:0] data_in;
input parity_bit;
output parity_error;

assign parity_error = ((^data_in)^parity_bit);

endmodule
/*
module parity(
    input [7:0] data_in, 
    output parity_bit  
);

assign parity_bit = ^data_in; 

endmodule

module parity_checker(
    input [7:0] data_in,  
    input    parity_bit,  
    output   parity_error
);

assign parity_error = (^(data_in) ^ parity_bit);

endmodule*/
