module tb_shift_register;

reg i_clk;
reg i_rstn;
reg i_data;

wire [7:0] o_data;

shift_register dut (

.i_clk(i_clk),
.i_rstn(i_rstn),
.i_data(i_data),
.o_data(o_data)

);

initial begin 
i_clk =0;
i_rstn = 0;
forever #5 i_clk =~i_clk;
end

initial begin 
#10 i_rstn =1; i_data =0;

repeat(64) begin
	@ (negedge i_clk);
	i_data = $random % 2;
end

#80 $finish;
end


endmodule
