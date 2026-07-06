module filp_flop(

i_clk,
i_rstn,
i_data,
o_data

);

input i_clk;
input i_rstn;
input [31:0] i_data;
output [31:0]o_data;

reg [31:0]o_data;

always @(posedge i_clk) begin
	if(!i_rstn) o_data<=31'd0;
	
	else begin

	o_data <= i_data;

	end 


end




 
endmodule
