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

and (w_snin[0], i_in[0],i_s[0],i_s[1],i_s[2]);
and (w_snin[1], i_in[1],i_s[0],w_ns[1],i_s[2]);
and (w_snin[2], i_in[2],i_s[0],i_s[1],w_ns[2]);
and (w_snin[3], i_in[3],i_s[0],w_ns[1],w_ns[2]);

and (w_snin[4], i_in[4],w_ns[0],w_ns[1],w_ns[2]);
and (w_snin[5], i_in[5],w_ns[0],w_ns[1],i_s[2]);
and (w_snin[6], i_in[6],w_ns[0],i_s[1],i_s[2]);
and (w_snin[7], i_in[7],w_ns[0],i_s[1],w_ns[2]);

or(o_out, w_snin[0],w_snin[1],w_snin[2],w_snin[3],w_snin[4],w_snin[5],w_snin[6],w_snin[7]);
endmodule
