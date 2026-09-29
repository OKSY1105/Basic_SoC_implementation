`timescale 1ns/1ps
module clog2 #(
	parameter DEPTH = 256
)(
	i_clk,
	i_rst,
	i_we,
	i_addr,
	i_din,
	o_dout
);
input i_clk, i_rst, i_we;
input [clog2(DEPTH)-1:0] i_addr;
input [7:0] i_din;
output [7:0] o_dout;

reg [7:0] o_dout;
reg [7:0] r_mem [DEPTH-1:0];

function integer clog2;
	input integer value;
	integer i;
	
	begin 
		clog2 =0;
		for (i = value-1; i > 0; i= i >>1) clog2 =clog2+1;
	end

endfunction

integer addr; 

always @(posedge i_clk or i_rst) begin
	
	if(i_rst) begin
		for(addr =0; addr < DEPTH; addr= addr+1)r_mem[addr]<=8'd0; 

		o_dout <= 8'd0;
	end

	else begin
		if(i_we) begin
			r_mem[i_addr] <= i_din;
			o_dout <=r_mem[i_addr];
		end

		else begin
			
			o_dout <=r_mem[i_addr];
		end

	end

end

endmodule


