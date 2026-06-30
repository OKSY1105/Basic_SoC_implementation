module MUX(



i_in1,
i_in2,
i_in3,
i_in4,
i_sel,
o_out

);



input i_in1;
input i_in2;
input i_in3;
input i_in4;

input [1:0] i_sel;

output o_out;

reg[2:0] o_out;
		
always @(*) begin
	case(i_sel) 
		2'b00 : o_out <= i_in1;
		2'b01 : o_out <= i_in2;
		2'b11 : o_out <= i_in3;
		2'b10 : o_out <= i_in4;
	endcase

end

endmodule


