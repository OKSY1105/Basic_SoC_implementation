module mux_8_1(

i_in,
i_s,
o_out


);

input [7:0] i_in;
input [2:0] i_s;
output o_out;

wire [7:0] w_snin;
wire [2:0] w_ns;

not(w_ns[0], i_s[0]);
not(w_ns[1], i_s[1]);
not(w_ns[2], i_s[2]);

and (w_snin[0], i_in[0],i_s[0],i_s[1],w_ns[2] );

endmodule
