module tb_filp_flop;

reg i_clk;
reg i_rstn;
reg [31:0] i_data;

wire [31:0] o_data;


initial begin
        $dumpfile ("./filp_flop.vcd");
        $dumpvars(0,tb_filp_flop) ;
end

filp_flop uut (
	.i_clk(i_clk),
	.i_rstn(i_rstn),
	.i_data(i_data),
	.o_data(o_data)
);

always #5 i_clk = ~i_clk;

initial begin
i_clk =0;
i_rstn =0; 
i_data = 32'd0; #5;

i_data = 32'd1024; #10;
i_data = 32'd1240; #10;
i_data = 32'd2024; #10;
i_data = 32'd1424; #10;
i_data = 32'd3024; #10;

$finish;





end



endmodule



