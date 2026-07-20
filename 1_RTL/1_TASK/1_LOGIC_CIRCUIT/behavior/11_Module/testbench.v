`timescale 1ns / 1ps
module testbench;

wire [1:0]     i_add_a;
wire [1:0]     i_add_b;
wire [1:0]     i_add_c;
wire [1:0]     i_add_d;
wire           i_add_sub_sel;
wire [7:0]     o_final_cal_out;
reg [8:0]      cnt;
integer file;

 
  module_top u_module_top (
    .i_add_a         ( i_add_a         ),
    .i_add_b         ( i_add_b         ),
    .i_add_c         ( i_add_c         ),
    .i_add_d         ( i_add_d         ),
    .i_add_sub_sel   ( i_add_sub_sel   ),
    .o_final_cal_out ( o_final_cal_out )
  );

 
  assign i_add_sub_sel = cnt[0];
  assign i_add_a = cnt[2:1];
  assign i_add_b = cnt[4:3];
  assign i_add_c = cnt[6:5];
  assign i_add_d = cnt[8:7];

  initial begin
    file = $fopen("output.txt", "w");
    
   
    cnt = 0;
    $monitor("i_add_a = %d, i_add_b = %d, i_add_c = %d, i_add_d = %d, i_add_sub_sel = %d, o_final_cal_out = %h", 
              i_add_a, i_add_b, i_add_c, i_add_d, i_add_sub_sel, o_final_cal_out);
    $fmonitor(file,"in_add_a = %d, in_add_b = %d, in_add_c = %d, in_add_d = %d, in_add_sub_sel = %d, final_cal_out = %h",
              i_add_a, i_add_b, i_add_c, i_add_d, i_add_sub_sel, o_final_cal_out);
    
  
    repeat(512) begin
      cnt = cnt + 1; #10;
    end
    #10;
    
    $fclose(file);
    $finish;
  end

endmodule
