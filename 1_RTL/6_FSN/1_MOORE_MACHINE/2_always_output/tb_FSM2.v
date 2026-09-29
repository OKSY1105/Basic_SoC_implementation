module tb_FSM2;

reg i_clk;
reg i_rstn;
reg i_go;
reg i_ws;

wire o_rd;
wire o_ds;


FSM2 DUT (

.i_clk(i_clk),
.i_rstn(i_rstn),
.i_go(i_go),
.i_ws(i_ws),
.o_rd(o_rd),
.o_ds(o_ds)


);

always #5 i_clk = ~i_clk;


initial begin
	i_clk = 1'b0; i_rstn = 1'b0;
	i_go=1'b0; i_ws= 1'b0;

	#100 i_rstn =1'b1;
	#100 i_go = 1'b1; i_ws= 1'b1;
	#100 i_ws = 1'b0;
	#100 i_rstn =1'b0;
	#100; $finish;

end

endmodule

