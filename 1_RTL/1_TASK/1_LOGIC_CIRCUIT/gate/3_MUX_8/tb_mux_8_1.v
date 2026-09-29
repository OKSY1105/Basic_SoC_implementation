module tb_mux_8_1;

reg [7:0] i_in;
reg [2:0] i_s;

//monitor siganl
wire o_out;

initial begin
	$dumpfile ("./mux_8_1.vcd");
	$dumpvars(0,tb_mux_8_1) ;
end


//coverage 100%
initial begin
	i_in =8'd0;
 	
	i_s = 3'b000; #10;
 	i_s = 3'b001; #10;
 	i_s = 3'b011; #10;
 	i_s = 3'b010; #10;
	i_s = 3'b110; #10;
	i_s = 3'b111; #10;
	i_s = 3'b101; #10;
	i_s = 3'b100; #10;
	$finish; 
end

mux_8_1 uut(


	.i_s(i_s),
	.i_in(i_in),
	.o_out(o_out)
);

endmodule
