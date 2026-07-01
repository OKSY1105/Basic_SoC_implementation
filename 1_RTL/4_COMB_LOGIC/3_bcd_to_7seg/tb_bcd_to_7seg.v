

module tb_bcd_to_7seg;

// stimulus signal
reg     [3:0] i_input   ;           
// // monitor signal
wire    [6:0] o_output     ;          
//
// // DUT instantiation
 bcd_to_7seg uut (
     .i_input(i_input),
     .o_output(o_output)
         );

//         // Dumpfile gen
initial begin
$dumpfile("./bcd_to_7seg.vcd"   );
$dumpvars(0, tb_bcd_to_7seg     );
end
//
//                 // apply stimulus
initial begin
//                     // monitoring
	$monitor("Time=%0t | i_bcd Input=%b | Seven Segment  Output=%b", $time, i_input, o_output);
//
//                             // apply stimulus
 	i_input = 4'b0000; #10; 
        i_input = 4'b0001; #10; 
        i_input = 4'b0010; #10; 
        i_input = 4'b0011; #10; 
        i_input = 4'b0100; #10; 
        i_input = 4'b0101; #10; 
        i_input = 4'b0110; #10; 
        i_input = 4'b0111; #10;  
        i_input = 4'b1000; #10;  
        i_input = 4'b1001; #10;  
       $finish ; 
end

endmodule
