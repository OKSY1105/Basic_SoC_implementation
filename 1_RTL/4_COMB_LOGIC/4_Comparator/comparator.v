module comparator(

i_in1,
i_in2,
o_out


);

input [31:0] i_in1;
input [31:0] i_in2;

output  [1:0] o_out;

always @(*) begin
	if (i_in1 > i_in2) o_out = 2'b01;
	else if (i_in1 == i_in2) o_out = 2'b11;
	else o_out = 2'b10;
end

endmodule
