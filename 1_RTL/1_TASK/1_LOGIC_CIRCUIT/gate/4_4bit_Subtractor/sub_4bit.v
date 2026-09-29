module sub_4bit(

i_A0,
i_A1,
i_A2,
i_A3,

i_B0,
i_B1,
i_B2,
i_B3,

o_out0,
o_out1,
o_out2,
o_out3,
o_over_flow
);


input i_A0, i_A1, i_A2, i_A3;
input i_B0, i_B1, i_B2, i_B3;

output o_out0, o_out1, o_out2, o_out3;
output o_over_flow;

wire w_c0 = 1;
wire w_c1,w_c2,w_c3;
wire w_xbc0,w_xbc1,w_xbc2,w_xbc3;
wire w_na0b0, w_na1b1, w_na2b2, w_na3b3;
wire w_xa0b0,w_xa1b1,w_xa2b2,w_xa3b3;
wire w_nc0x0, w_nc1x1, w_nc2x2,w_nc3x3;

xor(w_xbc0, i_B0,w_c0);
xor(o_out0, i_A0, w_xbc0, w_c0);
and(w_na0b0, i_A0,w_xbc0);
xor(w_xa0b0, i_A0, w_xbc0);
and(w_nc0x0, w_xa0b0, w_c0);
or(w_c1,w_na0b0,w_nc0x0);


xor(w_xbc1, i_B1,w_c0);
xor(o_out1, i_A1, w_xbc1, w_c1);
and(w_na1b1, i_A1,w_xbc1);
xor(w_xa1b1, i_A1, w_xbc1);
and(w_nc1x1, w_xa1b1, w_c1);
or(w_c2,w_na1b1,w_nc1x1);


xor(w_xbc2, i_B2,w_c0);
xor(o_out2, i_A2, w_xbc2, w_c2);
and(w_na2b2, i_A2,w_xbc2);
xor(w_xa2b2, i_A2, w_xbc2);
and(w_nc2x2, w_xa2b2, w_c2);
or(w_c3,w_na2b2,w_nc2x2);


xor(w_xbc3, i_B3,w_c0);
xor(o_out3, i_A3, w_xbc3, w_c3);
and(w_na3b3, i_A3,w_xbc3);
xor(w_xa3b3, i_A3, w_xbc3);
and(w_nc3x3, w_xa3b3, w_c3);
or(o_over_flow,w_na3b3,w_nc3x3);

endmodule
