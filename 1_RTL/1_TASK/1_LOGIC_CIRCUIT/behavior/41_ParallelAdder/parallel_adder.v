`timescale 1ns / 1ps
module parallel_adder #(
	parameter N = 4
)(
	i_a,
	i_b,
	o_sum
);

input [N-1:0] i_a;
input [N-1:0] i_b;
output [N:0] o_sum;

reg [N-1:0] w_sum;
reg  w_carry;

//assign o_sum = i_a + i_b;
integer i;
always @(*)begin
	w_carry =1'b0;
	
	for (i =0; i<N; i=i+1) begin
		w_sum[i] = i_a[i]^i_b[i]^w_carry;
		w_carry = (i_a[i]&i_b[i])|(i_b[i] & w_carry)|(i_a[i]&w_carry);
	end
end

assign o_sum ={w_carry,w_sum};


endmodule
