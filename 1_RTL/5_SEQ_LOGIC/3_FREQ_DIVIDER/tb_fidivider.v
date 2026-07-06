module tb_fidivider;

reg i_clk_in;
reg i_rstn;

wire o_clk_out;


fidivider #( .DIVISOR(10)
) divider(

	.i_clk_in(i_clk_in),
	.i_rstn(i_rstn),
	.o_clk_out(o_clk_out)

);


always #5 i_clk_in = ~i_clk_in;

initial begin

	i_clk_in =0;
	i_rstn =0;
	#20 i_rstn=1;
	repeat(200) @(posedge i_clk_in) ;
	$finish;
end



 

always @ (posedge i_clk_in) begin
	 $display("Time=%0t, clk_in=%b, clk_out=%b", $time, i_clk_in, o_clk_out);

end 

endmodule


