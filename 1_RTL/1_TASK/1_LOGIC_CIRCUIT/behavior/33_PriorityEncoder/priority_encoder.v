`timescale 1ns / 1ps
module priority_encoder(

	i_in,
	o_out,
	o_valid

);
input [3:0] i_in;
output [1:0] o_out;
output o_valid;

reg [1:0] o_out;
reg o_valid;

always@(*) begin
	casex(i_in)
		4'b0001 : begin 
			o_out <= 2'b00;
			o_valid <=1'b1;
		end

		4'b001x : begin
		       o_out <=2'b01;
	       	       o_valid <=1'b1;				       
		end
		 
		4'b01xx : begin
                       o_out <=2'b10;
		       o_valid <=1'b1;
                end

		4'b1xxx : begin
                       o_out <=2'b11;
                       o_valid <=1'b1;
                end

		default : begin
                        o_out <= 2'b00;
                        o_valid <=1'b0;
                end

	endcase
end
	
endmodule
