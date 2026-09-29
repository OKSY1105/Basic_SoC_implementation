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

reg [WIDTH-1:0] r_line_1;
reg [WIDTH-1:0] r_line_2;
reg [WIDTH-1:0] r_line_3;
reg [WIDTH-1:0] r_line_4;
reg [WIDTH-1:0] r_line_5;

always @(posedge i_clk or negedge i_rst_n)begin
	if(!i_rst_n) begin
		r_line_1 <=32'd0;
		r_line_2 <=32'd0;
		r_line_3 <=32'd0;
		r_line_4 <=32'd0;
		r_line_5 <=32'd0;
	end

	else begin
		r_line_1<= i_data;
		r_line_2<=r_line_1;
		r_line_3<=r_line_2;
		r_line_4<=r_line_3;
		r_line_5<=r_line_4;
	end

end


assign o_line1=r_line_1;
assign o_line2=r_line_2;
assign o_line3=r_line_3;
assign o_line4=r_line_4;
assign o_line5=r_line_5;


endmodule
