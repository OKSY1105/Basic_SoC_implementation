
module testbench;

  reg [1:0] sel;
  wire [1:0] normal_if;   
  wire [1:0] normal_case;   
  wire [1:0] normal_ternary;   
  wire [1:0] latch_if;   
  wire [1:0] latch_case;  
  
  integer file;  

 
  ifcase u_ifcase (
    .i_sel            ( sel            ),
    .o_normal_if      ( normal_if      ),
    .o_normal_case    ( normal_case    ),
    .o_normal_ternary ( normal_ternary ),
    .o_latch_if       ( latch_if       ),
    .o_latch_case     ( latch_case     )
  );

  initial begin
    
    file = $fopen("output.txt", "w");
    
    
    sel = 0;
    
    
    $fmonitor(file,"sel = %d, normal_if = %d, normal_case = %d, normal_ternary = %d, latch_if = %d, latch_case = %d", 
              sel, normal_if, normal_case, normal_ternary, latch_if, latch_case);
    $monitor("sel = %d, normal_if = %d, normal_case = %d, normal_ternary = %d, latch_if = %d, latch_case = %d", 
             sel, normal_if, normal_case, normal_ternary, latch_if, latch_case);
             
    repeat(8) begin
      sel = sel + 1; 
      #10;
    end
    
    #10;
    
    
    $fclose(file);
    $finish;
  end

endmodule