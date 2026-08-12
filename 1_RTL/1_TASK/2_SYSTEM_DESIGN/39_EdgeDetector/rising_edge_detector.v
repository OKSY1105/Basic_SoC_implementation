`timescale 1ns/ 1ps
module rising_edge_detector(
	i_clk,
	i_signal,
	o_edge_detected
);
input i_clk;
input i_signal;
output o_edge_detected;

reg o_edge_detected;
reg r_pre_signal;
always @(posedge i_clk)begin
	
	r_pre_signal <= i_signal;
	
	o_edge_detected <= (i_signal & ~(r_pre_signal));
	
end
endmodule
