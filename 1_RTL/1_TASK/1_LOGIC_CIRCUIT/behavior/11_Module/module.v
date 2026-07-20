`timescale 1ns / 1ps
module add_name (

i_add_a,
i_add_b,
o_out_sum
);

input [1:0] i_add_a;
input [1:0] i_add_b;
output [2:0] o_out_sum;

assign o_out_sum = i_add_a + i_add_b;

endmodule

module add_position( 

i_add_c,
i_add_d,
o_out_sum2
);

input [1:0] i_add_c;
input [1:0] i_add_d;
output [2:0] o_out_sum2;

assign o_out_sum2 = i_add_c + i_add_d;

endmodule

module add_sub(

i_add_a,
i_add_b,
i_add_sub_sel,
o_cal_out
);

input [2:0] i_add_a;
input [2:0] i_add_b;
input i_add_sub_sel;

output [3:0] o_cal_out;


reg [3:0] o_cal_out;


always @(*) begin
	o_cal_out = 8'd0;

	if(i_add_sub_sel) o_cal_out = i_add_a - i_add_b;
       else o_cal_out  = i_add_a + i_add_b;	



end	

endmodule


module module_top(

i_add_a,
i_add_b,
i_add_c,
i_add_d,
i_add_sub_sel,
o_final_cal_out
);

input [1:0] i_add_a;
input [1:0] i_add_b;
input [1:0] i_add_c;
input [1:0] i_add_d;
input i_add_sub_sel;

output [7:0] o_final_cal_out;

wire [2:0] o_out_sum;
wire [2:0] o_out_sum2;

add_name uut (.i_add_a(i_add_a), .i_add_b(i_add_b), .o_out_sum(o_out_sum));
add_position uut2 (.i_add_c(i_add_c), .i_add_d(i_add_d), .o_out_sum2(o_out_sum2));

add_sub dut1 ( .i_add_a(o_out_sum), .i_add_b(o_out_sum2), .i_add_sub_sel(i_add_sub_sel), .o_cal_out(o_final_cal_out[3:0]));
add_sub dut2 ( .i_add_a(o_out_sum), .i_add_b(o_out_sum2), .i_add_sub_sel(~i_add_sub_sel), .o_cal_out(o_final_cal_out[7:4]));


endmodule

