module multi_2bit(


i_A0,
i_A1,
i_B0,
i_B1,
o_out0,
o_out1,
o_out2,
o_out3

);

input i_A0, i_A1, i_B0, i_B1;
output o_out0, o_out1, o_out2, o_out3;

wire w_na0b1, w_na1b0, w_na1b1;
wire w_carry;

and(o_out0 , i_A0, i_B0);
and(w_na0b1, i_A0, i_B1);
and(w_na1b0, i_A1, i_B0);
xor(o_out1, w_na0b1, w_na1b0);
and(w_carry, w_na0b1, w_na1b0);
and(w_na1b1, i_A1, i_B1);
xor(o_out2, w_carry,w_na1b1);
and(o_out3, w_carry,w_na1b1);

endmodule
