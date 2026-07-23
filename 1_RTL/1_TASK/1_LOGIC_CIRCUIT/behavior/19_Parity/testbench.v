`timescale 1ns / 1ps
module testbench;

  reg  [7:0] data_in;
  wire parity_bit;   
  wire parity_error;   
  integer file;  


  parity u_parity (
    .data_in      (  data_in      ),
    .parity_bit   (  parity_bit   )
  );

  parity_checker u_parity_checker (
    .data_in      (  data_in      ),
    .parity_bit   (  1'b1         ),
    .parity_error (  parity_error )
  );

  
  initial begin
    forever begin
      @(data_in);
        $display("data_in = %b, parity_bit = %d, parity_error = %d ", data_in, parity_bit, parity_error);
        $fdisplay(file,"data_in = %b, parity_bit = %d, parity_error = %d ", data_in, parity_bit, parity_error);
    end
  end
  
  initial begin
    file = $fopen("answer.txt", "w");
    data_in = 0;
    #5;
    repeat(255) #1 data_in = data_in + 8'd1;
    #5;
    $fclose(file);
    $finish;
  end


endmodule

