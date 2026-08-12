`timescale 1ns/1ps
/*module msb_one_extractor(

	i_data_in,
	o_data_out
);

input [7:0] i_data_in;
output [7:0] o_data_out;

reg [7:0] r_result;
reg r_found;

integer i;

always @(*) begin
	r_result =8'd0;
	r_found =1'b1;
	for (i=7;i>=0; i=i-1)begin
		if(r_found && i_data_in[i])begin
		       	r_result[i] =1'b1;
			r_found=1'b0;
			
		end
	end
end
assign o_data_out = r_result;
endmodule
*/

module msb_one_extractor(

        i_data_in,
        o_data_out
);

input [7:0] i_data_in;
output [7:0] o_data_out;

reg [7:0] r_result;
always @(*) begin

	casex(i_data_in)
		8'b1xxxxxxx : r_result = 8'b10000000;
		8'bx1xxxxxx : r_result = 8'b01000000;
		8'bxx1xxxxx : r_result = 8'b00100000;
		8'bxxx1xxxx : r_result = 8'b00010000;
		8'bxxxx1xxx : r_result = 8'b00001000;
		8'bxxxxx1xx : r_result = 8'b00000100;
		8'bxxxxxx1x : r_result = 8'b00000010;
		8'bxxxxxxx1 : r_result = 8'b00000001;
		default : r_result =8'd0;
	endcase
 
end
assign o_data_out = r_result;
endmodule
