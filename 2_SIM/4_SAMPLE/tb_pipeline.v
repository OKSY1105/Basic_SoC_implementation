`timescale 1ns/1ps


module tb_pipeline;

reg clk = 0;
reg rst_n;
reg [9:0] i_in1;
reg [9:0] i_in2;
reg [9:0] i_in3;

wire [11:0] o_out;


initial begin 
clk =0;
forever #5 clk= ~clk;

end

initial begin
i_in1=0;
i_in2=0;
i_in3=0;

rst_n = 0; #5 rst_n=1;


#5   i_in1= 10'd1; 
     i_in2= 10'd2; 
     i_in3= 10'd3;
 
#20  i_in1= 10'd4;
     i_in2= 10'd5;
     i_in3= 10'd6;  

#60 $finish;
end
pipeline DUT (
 
.clk(clk),
.rst_n(rst_n),
.i_in1(i_in1),
.i_in2(i_in2),
.i_in3(i_in3),
.o_out(o_out)

);

initial begin
	$dumpfile("./pipline.vcd")   ;
	$dumpvars(0, DUT)	     ;
end
endmodule
