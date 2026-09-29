module tb_MUX;

reg i_in1;
reg i_in2;
reg i_in3;
reg i_in4;
reg [1:0] i_sel;

//monitor siganl
wire o_out;

initial begin
	$dumpfile ("./mux.vcd");
	$dumpvars(0,tb_MUX) ;
end


//coverage 100%
initial begin
	i_in1 =1'b0;i_in2 =1'b1; i_in3=1'b0; i_in4 = 1'b1;
 	
	i_sel = 2'b00; #10;
 	i_sel = 2'b01; #10;
 	i_sel = 2'b11; #10;
 	i_sel = 2'b10; #10;
	
	$finish; 
end

MUX uut(


	.i_sel(i_sel),
	.i_in1(i_in1),
	.i_in2(i_in2),
	.i_in3(i_in3),
	.i_in4(i_in4),
	.o_out(o_out)
);

endmodule
