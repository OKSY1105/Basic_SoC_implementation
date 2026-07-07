module tb_multi_2bit;

reg [1:0] i_A, i_B ;
wire [3:0]  o_out;
wire o_over_flow;

multi_2bit uut(
.i_A0(i_A[0]),.i_A1(i_A[1]),
.i_B0(i_B[0]),.i_B1(i_B[1]),
.o_out0(o_out[0]),.o_out1(o_out[1]),.o_out2(o_out[2]),.o_out3(o_out[3])

);

initial begin
	$monitor("A=%b B=%b | o_out=%b o_over_flow = %b", i_A, i_B, o_out, o_over_flow);
	
	i_A=2'b11; i_B=2'b11; #10;
	i_A=2'b11; i_B=2'b01; #10;
	i_A=2'b11; i_B=2'b10; #10;
	i_A=2'b11; i_B=2'b00; #10;

	i_A=2'b10; i_B=2'b11; #10;
        i_A=2'b10; i_B=2'b01; #10;
        i_A=2'b10; i_B=2'b10; #10;
        i_A=2'b10; i_B=2'b00; #10;

	i_A=2'b01; i_B=2'b11; #10;
        i_A=2'b01; i_B=2'b01; #10;
        i_A=2'b01; i_B=2'b10; #10;
        i_A=2'b01; i_B=2'b00; #10;

	i_A=2'b00; i_B=2'b11; #10;
        i_A=2'b00; i_B=2'b01; #10;
        i_A=2'b00; i_B=2'b10; #10;
        i_A=2'b00; i_B=2'b00; #10;

	


$finish;
end


endmodule
