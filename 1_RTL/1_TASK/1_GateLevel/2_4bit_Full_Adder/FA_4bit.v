module FA_4bit(

i_A0,
i_B0,

i_A1,
i_B1,

i_A2,
i_B2,

i_A3,
i_B3,

o_out0,
o_out1,
o_out2,
o_out3,
o_over_flow
);
input i_A0; input i_A1; input i_A2; input i_A3; 

input i_B0; input i_B1; input i_B2; input i_B3;

output o_out0; output o_out1; output o_out2; output o_out3; output o_over_flow; 

wire w_And0; wire w_And1; wire w_And2; wire w_And3;
wire w_Xor0; wire w_Xor1; wire w_Xor2; wire w_Xor3;
wire w_xnd0; wire w_xnd1; wire w_xnd2; wire w_xnd3;

wire w_carry0 =1'b0 ; wire w_carry1; wire w_carry2; wire w_carry3; 

xor (o_out0, i_A0, i_B0, w_carry0);
and (w_And0, i_A0,i_B0);
xor (w_Xor0, i_A0, i_B0);
and (w_xnd0,w_Xor0, w_carry0);
or(w_carry1,w_And0,w_xnd0);

xor (o_out1, i_A1, i_B1, w_carry1);
and (w_And1, i_A1,i_B1);
xor (w_Xor1, i_A1, i_B1);
and (w_xnd1,w_Xor1, w_carry1);
or(w_carry2,w_And1,w_xnd1);

xor (o_out2, i_A2, i_B2, w_carry2);
and (w_And2, i_A2,i_B2);
xor (w_Xor2, i_A2, i_B2);
and (w_xnd2,w_Xor2, w_carry2);
or(w_carry3,w_And2,w_xnd2);

xor (o_out3, i_A3, i_B3, w_carry3);
and (w_And3, i_A3,i_B3);
xor (w_Xor3, i_A3, i_B3);
and (w_xnd3,w_Xor3, w_carry3);
or(o_over_flow,w_And3,w_xnd3);

endmodule
