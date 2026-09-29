`timescale 1ns / 1ps

module alu_32b(

i_a,
i_b,
i_op,
o_result,
o_zero,
o_overflow
);
input [31:0] i_a, i_b;
input [3:0] i_op;
output [31:0] o_result;
output o_zero , o_overflow;

reg [31:0] o_result;
reg o_zero, o_overflow;

always @(*) begin
	case(i_op)
		4'd0 : begin
			o_result = i_a+i_b;
			if(o_result == 32'd0) o_zero =1'b1;
		       else o_zero = 1'b0;
	       		if(o_result[31] != (i_a[31] ^ i_b[31])) o_overflow =1'b1;
			else o_overflow =1'b0;

		end
		4'd1 : begin
			o_result = i_a-i_b;
                        if(o_result == 32'd0) o_zero =1'b1;
                       else o_zero = 1'b0;
                        if(o_result[31] != (i_a[31] ^ i_b[31])) o_overflow =1'b1;
                        else o_overflow =1'b0;

		end
		4'd2 :begin
                        o_result = i_a & i_b;
                        if(o_result == 32'd0) o_zero =1'b1;
                       else o_zero = 1'b0;
		       o_overflow =1'b0;

                end

		4'd3 :begin
                        o_result = i_a | i_b;
                        if(o_result == 32'd0) o_zero =1'b1;
                       else o_zero = 1'b0;
		       o_overflow =1'b0;
                end

		4'd4 :begin
                        o_result = i_a ^ i_b;
                        if(o_result == 32'd0) o_zero =1'b1;
                       else o_zero = 1'b0;
		       o_overflow =1'b0;
                end

		4'd5 :begin
		       	o_result = ~(i_a);
			o_zero = (o_result == 0) ? 1'b1 : 1'b0;
			o_overflow =1'b0;
		end	
                
		4'd6 :begin
                        o_result = i_a << i_b ;
                        o_zero = (o_result == 0) ? 1'b1 : 1'b0;
			o_overflow =1'b0;
                end

                4'd7 :begin
                        o_result = i_a >> i_b;
                        o_zero = (o_result == 0) ? 1'b1 : 1'b0;
			o_overflow =1'b0;
                end

		4'd8 :begin
                        o_result = $signed(i_a) >>> i_b;
                        o_zero = (o_result == 0) ? 1'b1 : 1'b0;
			o_overflow =1'b0;
                end

                4'd9 : begin
                        o_result = ($signed(i_a) < $signed(i_b)) ? 32'd1 : 32'd0;
                        o_zero = (o_result == 0) ? 1'b1 : 1'b0;
			o_overflow =1'b0;
                end

                4'd10 :begin
                        o_result = ($unsigned(i_a) < $unsigned(i_b)) ? 32'd1 : 32'd0;
                        o_zero = (o_result == 0) ? 1'b1 : 1'b0;
			o_overflow =1'b0;
                end

		default :begin
		       	o_result =32'd0;
			o_zero = 1'b1;
			o_overflow  = 32'd0;
		end
	endcase

end

endmodule
