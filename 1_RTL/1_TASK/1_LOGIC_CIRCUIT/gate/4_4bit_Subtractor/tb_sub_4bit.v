module tb_sub_4bit;

reg [3:0] i_A, i_B ;
wire [3:0]  o_out;
wire o_over_flow;

sub_4bit uut(
.i_A0(i_A[0]),.i_A1(i_A[1]),.i_A2(i_A[2]),.i_A3(i_A[3]),
.i_B0(i_B[0]),.i_B1(i_B[1]),.i_B2(i_B[2]),.i_B3(i_B[3]),
.o_out0(o_out[0]),.o_out1(o_out[1]),.o_out2(o_out[2]),.o_out3(o_out[3]),
.o_over_flow(o_over_flow)

);

initial begin
	$monitor("A=%b B=%b | o_out=%b o_over_flow = %b", i_A, i_B, o_out, o_over_flow);
	
	i_A=4'b0000; i_B=4'b1000; #10;
	i_A=4'b0111; i_B=4'b1000; #10;
	i_A=4'b1100; i_B=4'b0101; #10;
	i_A=4'b0110; i_B=4'b1011; #10;
	i_A=4'b0100; i_B=4'b1000; #10;
	i_A=4'b0101; i_B=4'b1001; #10;
	i_A=4'b1111; i_B=4'b1000; #10;
	


$finish;
end


endmodule
