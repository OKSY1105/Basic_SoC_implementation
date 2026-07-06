module tb_simple_register;

parameter WIDTH = 32;

reg i_clk;
reg i_rstn;
reg i_wen;
reg [WIDTH-1:0] i_wdata;

wire [WIDTH-1 :0] o_rdata; 

simple_register #(.WIDTH(WIDTH)
) uut(
	.i_clk(i_clk),
	.i_rstn(i_rstn),
	.i_wen(i_wen),
	.i_wdata(i_wdata),
	.o_rdata(o_rdata)

);

initial begin
	i_clk =0;
	forever #5 i_clk = ~i_clk;
end

initial begin

i_rstn = 1'b0 ; i_wen = 1'b0; i_wdata = 0;

#10 i_rstn =1'b1;

#10 i_wen =1; i_wdata = 1024;
#10 i_wen =0;

#10 $display ("Read Data : %d ", o_rdata);

$finish;


end

endmodule
