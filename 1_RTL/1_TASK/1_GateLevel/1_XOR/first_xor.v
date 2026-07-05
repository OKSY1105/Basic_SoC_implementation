module first_xor(
i_in1,
i_in2,
o_out
);

input i_in1;
input i_in2;
output o_out;

wire in1_bar, in2_bar;
wire w_and1, w_and2 ;

not u_not_in1 (in1_bar, i_in1);
not u_not_in2 (in2_bar, i_in2);

and u_and1 (w_and1, in1_bar, i_in2);
and u_and2 (w_and2, in2_bar, i_in1);

or u_or(o_out, w_and1, w_and2);


endmodule
