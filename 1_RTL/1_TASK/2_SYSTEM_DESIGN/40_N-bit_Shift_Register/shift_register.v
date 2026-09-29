`timescale 1ns/1ps
module shift_register #(
       parameter N =4
)(
	i_clk,
	i_rst,
	i_data_in,
	i_shift_length,
	i_dir,
	o_data_out
);

input i_clk, i_rst, i_dir;
input [N-1:0] i_data_in;
input [clog2(N)-1:0] i_shift_length;
output [N-1:0] o_data_out;

reg [N-1:0] o_data_out;


function integer clog2(input integer N);
	integer i;
	
	begin
		clog2=0;
		
		for (i=0 ; N > 0 ; i=i+1) begin
			N = N >>1;
			clog2 = i+1;
		end

	end
endfunction

	
always @(posedge i_clk or posedge i_rst) begin
	if(i_rst) o_data_out <=0;

	else begin
		case(i_dir)
			1'b0 : o_data_out <= (i_data_in << i_shift_length);
			1'b1 : o_data_out <= (i_data_in >> i_shift_length);
		endcase
	end
end	
		

endmodule
	
