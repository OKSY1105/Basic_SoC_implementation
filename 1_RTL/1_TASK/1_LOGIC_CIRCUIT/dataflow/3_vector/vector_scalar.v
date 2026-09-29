module vector_scalar(


i_vector_0,
o_scala_0,
o_scala_1,
o_scala_2,
o_scala_3,

i_scala_1, 
o_vector_1,


i_vector_2,
o_vector_2,

i_vector_3_0,
i_vector_3_1,
i_vector_3_2,
o_vector_3


);

input [3:0] i_vector_0;
output o_scala_0;
output o_scala_1;
output o_scala_2;
output o_scala_3;

assign o_scala_0 = i_vector_0[0];
assign o_scala_1 = i_vector_0[1];
assign o_scala_2 = i_vector_0[2];
assign o_scala_3 = i_vector_0[3];


input i_scala_1;
output  [3:0] o_vector_1;

assign o_vecotr_1 = {i_scala_1,i_scala_1, i_scala_1,i_scala_1};

input [12:0] i_vector_2;
output [6:0] o_vector_2;

assign o_vector_2[0] = i_vector_2[0];
assign o_vector_2[1] = i_vector_2[1] & i_vector_2[2];
assign o_vector_2[2] = ~(i_vector_2[3] & i_vector_2[4]);
assign o_vector_2[3] = i_vector_2[5] | i_vector_2[6];
assign o_vector_2[4] = ~(i_vector_2[7] | i_vector_2[8]);
assign o_vector_2[5] = i_vector_2[9] ^ i_vector_2[10];
assign o_vector_2[6] = ~(i_vector_2[11] ^ i_vector_2[12]);

input [3:0] i_vector_3_0;
input [3:0] i_vector_3_1;
input [3:0] i_vector_3_2;
output [11:0] o_vector_3;
assign o_vector_3[0] = i_vector_3_0[0];
assign o_vector_3[1] = i_vector_3_0[1];
assign o_vector_3[2] = i_vector_3_0[2];
assign o_vector_3[3] = i_vector_3_0[3];
assign o_vector_3[4] = i_vector_3_1[0];
assign o_vector_3[5] = i_vector_3_1[1];
assign o_vector_3[6] = i_vector_3_1[2];
assign o_vector_3[7] = i_vector_3_1[3];
assign o_vector_3[8] = i_vector_3_2[0];
assign o_vector_3[9] = i_vector_3_2[1];
assign o_vector_3[10] =i_vector_3_2[2];
assign o_vector_3[11] =i_vector_3_2[3];

endmodule
