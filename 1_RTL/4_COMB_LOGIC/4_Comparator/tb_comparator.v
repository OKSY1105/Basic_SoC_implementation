module tb_comparator;

// stimulus
 reg [31:0] i_in1, i_in2;
//
// // monitor
 wire o_out1, o_out2, o_out3;
//
//
comparator uut (
  .i_in1(i_in1),
  .i_in2(i_in2),
  .o_out1(o_out1),
  .o_out2(o_out2),
  .o_out3(o_out3)
 );


initial begin
  // system task for monitoring
     $monitor("%0t\t %b\t %b\t %b\t %b\t %b", $time, i_a, i_b, o_greater,
     o_equal, o_less);
  
  // apply stimulus
       i_a = 32'd1024; i_b = 32'd1025; #10; 
       i_a = 32'd2048; i_b = 32'd2048; #10; 
       i_a = 32'd1111; i_b = 32'd1000; #10; 
       i_a = 32'd2781; i_b = 32'd3111; #10; 
       i_a = 32'd3010; i_b = 32'd2101; #10; 
       i_a = 32'd0511; i_b = 32'd1051; #10; 
       i_a = 32'd1100; i_b = 32'd1110; #10; 
       i_a = 32'd0; i_b = 32'd1111; #10; 
  //
  //                       // finish simulation
        #10 $finish;
 	end

endmodule

