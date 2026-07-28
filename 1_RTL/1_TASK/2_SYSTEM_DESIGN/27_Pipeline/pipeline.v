`timescale 1ns / 1ps
module pipeline #( 
	parameter WIDTH =32
)(

	i_clk,
	i_rst_n,
	i_data,
	o_line1,
	o_line2,
	o_line3,
	o_line4,
	o_line5
);

input i_clk, i_rst_n;
input [WIDTH-1:0] i_data;
output [WIDTH-1:0] o_line1;
output [WIDTH-1:0] o_line2;
output [WIDTH-1:0] o_line3;
output [WIDTH-1:0] o_line4;
output [WIDTH-1:0] o_line5;

reg [WIDTH-1:0] o_line1;
reg [WIDTH-1:0] o_line2;
reg [WIDTH-1:0] o_line3;
reg [WIDTH-1:0] o_line4;
reg [WIDTH-1:0] o_line5;

always @(posedge i_clk or negedge i_rst_n)begin
	if(!i_rst_n) begin
		o_line1 <=32'd0;
		o_line2 <=32'd0;
		o_line3 <=32'd0;
		o_line4 <=32'd0;
		o_line5 <=32'd0;
	end

	else begin
		o_line1<= i_data;
		o_line2<=o_line1;
		o_line3<=o_line2;
		o_line4<=o_line3;
		o_line5<=o_line4;
	end

end

endmodule
