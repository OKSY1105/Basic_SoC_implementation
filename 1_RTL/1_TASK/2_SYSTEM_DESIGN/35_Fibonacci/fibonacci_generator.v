`timescale 1ns /1ps
module fibonacci_generator(
	i_clk,
	i_rst,
	o_fib_out
);

input i_clk , i_rst;
output o_fib_out;

reg [31:0] o_fib_out;
reg [31:0] r_pre_fib;

always @ (posedge i_clk or posedge i_rst)begin
	if(i_rst)begin
	       	o_fib_out <= 32'd1;
		r_pre_fib <=32'd0;
	end

	else begin
		o_fib_out <= o_fib_out + r_pre_fib;
		r_pre_fib <=o_fib_out;
	end
end

endmodule
