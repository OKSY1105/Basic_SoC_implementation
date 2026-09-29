module bcd_to_7seg(

i_input,
o_output

);

input [3:0] i_input;
output [7:0] o_output;


reg [6:0] o_output;


always @ (*) begin
	case(i_input)
	4'd0 : o_output =7'b111_1110;
	4'd1 : o_output =7'b011_0000;
	4'd2 : o_output =7'b110_1100;
	4'd3 : o_output =7'b111_1001;
	4'd4 : o_output =7'b011_0011;
	4'd5 : o_output =7'b101_1011;
	4'd6 : o_output =7'b101_1111;
	4'd7 : o_output =7'b111_0000;
	4'd8 : o_output =7'b111_1111;
	4'd9 : o_output =7'b111_0111;
	endcase


end

endmodule
