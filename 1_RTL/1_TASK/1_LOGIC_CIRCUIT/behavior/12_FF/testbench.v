`timescale 1ns / 1ps

module testbench;

reg clk;
reg reset;
reg d;

wire q;
integer file;  

// 수정된 flipflop 모듈 포트 이름에 맞춰 매핑
flipflop u_flipflop (
    .i_clk(clk),
    .i_reset(reset),
    .i_in(d),
    .o_out(q)
);

always #5 clk = ~clk;

initial begin
    file = $fopen("output.txt", "w");
    forever begin
        @(posedge clk);
        $display("reset = %d, d=%b, q=%b ", reset, d, q);
        $fdisplay(file, "reset = %d, d=%b, q=%b ", reset, d, q);
    end
end

initial begin
    clk = 0;
    reset = 1;
    d = 0;
    
    @(posedge clk);
    #1 reset <= 0;
    
    @(posedge clk);
    d <= 1;
    
    @(posedge clk);
    d <= 0;
    
    @(posedge clk);
    #1 reset <= 1;
    
    @(posedge clk);
    d <= 1;
    
    @(posedge clk);
    #1 reset <= 0;
    
    @(posedge clk);
    d <= 0;
    
    @(posedge clk);
    #10;
    
    $fclose(file);
    $finish;
end

endmodule





