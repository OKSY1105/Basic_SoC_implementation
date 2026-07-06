module tb_FSM1;

reg i_clk;
reg i_rstn;
reg i_go;
reg i_we;

wire o_rd;
wire o_ds;


FSM1 DUT (

.i_clk(i_clk),
.i_rstn(i_rstn),
.i_go(i_go),
.i_we(i_we),
.o_rd(o_rd),
.o_ds(o_ds)


);

always #5 i_clk = ~i_clk;


initial begin
	i_clk = 1'b0; i_rstn = 1'b0;
	i_go=1'b0; i_we= 1'b0;

	#100 i_rstn =1'b1;
	#100 i_go = 1'b1; i_we= 1'b1;
	#100 i_we = 1'b0;
	#100 i_rstn =1'b0;
	#100; $finish;

end

endmodule

