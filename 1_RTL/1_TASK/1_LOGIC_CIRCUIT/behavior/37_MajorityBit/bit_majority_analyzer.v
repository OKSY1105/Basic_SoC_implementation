/*`timescale 1ns/1ps
module bit_majority_analyzer(
	i_in1,
	i_in2,
	i_in3,
	o_result
);

input [7:0] i_in1;
input [7:0] i_in2;
input [7:0] i_in3;
output [7:0] o_result;

reg [2:0] w_check;
reg [7:0] w_result;
integer i;

always@(*)begin
	

	for(i =0; i<8;i=i+1) begin
		w_check = {i_in1[i], i_in2[i], i_in3[i]};
		if(w_check==3'd3|| w_check==3'd5 || w_check ==3'd6||w_check==3'd7) w_result[i]=1;
		else w_result[i]=0;
	end
end

assign o_result = w_result;

endmodule
*/


`timescale 1ns/1ps
module bit_majority_analyzer(
        i_in1,
        i_in2,
        i_in3,
        o_result
);

input [7:0] i_in1;
input [7:0] i_in2;
input [7:0] i_in3;
output [7:0] o_result;

assign o_result = (i_in1 &i_in3) |(i_in2&i_in3)|(i_in1&i_in2);

endmodule

