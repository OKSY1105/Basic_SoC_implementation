module tb_data_bus_driver();

// stimulus signal
reg [7:0]   i_in1            ;      
reg [7:0]   i_in2            ;      
reg         i_en1              ;              
reg         i_en2              ;              
// // monitor signal
wire [7:0] o_bus_data           ;   
//
// // DUT instantiation 
data_bus_driver uut (
     .i_in1   (i_in1   )   ,
     .i_in2   (i_in2   )   ,
     .i_en1     (i_en1     )   ,
     .i_en2     (i_en2     )   ,
     .o_bus_data (o_bus_data )
 );

initial begin
    $dumpfile("./data_bus_driver.vcd"   );
    $dumpvars(0, tb_data_bus_driver     );
end
// Test Scenario 
 initial begin
//     // system task for monitoring
         $monitor("Time=%0t | en_A=%b, data_A=%b | en_B=%b, data_B=%b| bus_data=%b",
	 $time, i_en1, i_in1, i_en2, i_in2,o_bus_data);
//                          // init
         i_in1 <= 8'haa; i_in2 <= 8'hcc;
//                                  // apply stimulus
          i_en1 <= 0; i_en2 <= 0; #10;  
          i_en1 <= 1; i_en2 <= 0; #10; 
          i_en1 <= 0; i_en2 <= 1; #10; 
          i_en1 <= 1; i_en2 <= 1; #10; 
          i_en1 <= 0; i_en2 <= 0; #10; 
      $finish;
   end
endmodule



























