module tb_first_xor;

reg i_in1, i_in2;
wire o_out;

first_xor uut(
.i_in1(i_in1),
.i_in2(i_in2),
.o_out(o_out)

);

initial begin
	$monitor("Time=%0t | i_in1=%b, i_in2=%b | o_out=%b", $time, i_in1, i_in2, o_out);
	
	i_in1=0; i_in2=0; #10;
	i_in1=1; i_in2=0; #10;
	i_in1=1; i_in2=1; #10;
	i_in1=0; i_in2=1; #10;


$finish;
end


endmodule
