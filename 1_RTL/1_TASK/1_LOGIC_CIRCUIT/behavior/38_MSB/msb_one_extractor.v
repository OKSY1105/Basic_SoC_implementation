`timescale 1ns/1ps
module msb_one_extractor(

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

