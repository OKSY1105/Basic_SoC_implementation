`timescale 1ns /1 ps
module parallel_processor #(
	parameter DATA_WIDTH =8,
	parameter NUM_PATHS = 4
)(
	i_clk,
	i_rst,
	i_data_in,
	i_data_valid,
	o_data_out,
	o_data_out_valid
);


input i_clk, i_rst;
input [ DATA_WIDTH-1 :0] i_data_in;
input i_data_valid;
output [(DATA_WIDTH * NUM_PATHS) -1 :0] o_data_out;
output o_data_out_valid;

reg [(DATA_WIDTH * NUM_PATHS) -1 :0] o_data_out;
reg o_data_out_valid;




always @(posedge i_clk or posedge i_rst) begin
	if(i_rst) begin
		o_data_out <= { (DATA_WIDTH * NUM_PATHS) {1'b0} };
		o_data_out_valid <=1'b0;
	end

	else begin
		 	
		o_data_out_valid <= i_data_valid;
	
		if(i_data_valid) begin
			o_data_out [7 :0]  <= i_data_in+1'b1;
			o_data_out [15:8]  <= i_data_in-1'b1;
			o_data_out [23:16]  <= i_data_in ^8'hFF;
			o_data_out [31:24]  <= i_data_in & 8'hAA;
			
		end

	
	
	end

end



endmodule
