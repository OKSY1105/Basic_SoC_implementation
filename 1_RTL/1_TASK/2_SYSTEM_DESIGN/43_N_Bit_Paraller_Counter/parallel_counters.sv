`timescale 1ns/ 1ps

module parallel_counters #(
	parameter N = 3,
	parameter M = 4
)(
	i_clk,
	i_rst,
	i_enable,
	o_count
);

input i_clk, i_rst;
input [N-1:0]i_enable;
output [M-1:0] o_count [N-1:0];

reg [M-1:0] o_count [N-1:0];
integer i;

always @(posedge i_clk, posedge i_rst) begin
	if(i_rst) begin
		for(i=0; i<N ; i=i+1)begin
			o_count[i] <= {M{1'b0}};
		end
	end

	else begin
		for(i=0; i<N;i=i+1) begin
			if(i_enable[i] ==1)begin
				o_count[i] <= o_count[i]+1;
			end

			else o_count[i]<=o_count[i];
		end
	end
end


endmodule	

