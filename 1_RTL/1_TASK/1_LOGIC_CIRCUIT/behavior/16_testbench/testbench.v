`timescale 1ns / 1ps
module testbench;

// Signal declarations 
reg clk;
reg reset;
reg enable;
wire [3:0] count;
reg [3:0] expected_count;
reg [4:0] error_count;
integer file;  

// DUT 
counter_4bit dut (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .count(count)
);

// Clock generation
always #5 clk = ~clk;

// test scenario
initial begin
    file = $fopen("output.txt", "w");
    $timeformat(-9, 0, "ns", 10); // -9: ns, 0: decimal place, "ns": unit, 10:minimum field width
    // Initialization
    clk = 0;
    reset = 1;
    enable = 0;
    expected_count = 4'b0000;
    error_count = 0;
    
    // Release reset
    #10 reset = 0;
    
    //Check 1
    @(posedge clk);
    enable <= 1;
    repeat(16) begin
        @(posedge clk);
        expected_count <= expected_count + 1;
        //Check 2
        if(expected_count == 13) begin
            #1 force dut.count = 7;
        end 
        check_count();
    end
    // Check 3
    @(posedge clk);
    enable <= 0;
    @(posedge clk);
    #1 release dut.count; 
    expected_count <= 4'd7;
    repeat(5) begin
        @(posedge clk);
        check_count();
    end
    
    // Check 4
    @(posedge clk);
    reset <= 1;
    expected_count <= 4'b0000;
    @(posedge clk);
    check_count();
    @(posedge clk);
    
    // result
    if (error_count == 0) begin
        $display("[PASS] All tests passed successfully!");
        $fdisplay(file,"[PASS] All tests passed successfully!");
    end else begin
        $display("[FAIL] %0d errors occurred during the test.", error_count);
        $fdisplay(file,"[FAIL] %0d errors occurred during the test.", error_count);
    end
    
    
    #10 $finish;
end

// checker task
task check_count;
    if (count !== expected_count) begin
        $display("Error at time %0t: Expected count = %b, Actual count = %b", $time, expected_count, count);
        $fdisplay(file,"Error at time %0t: Expected count = %b, Actual count = %b", $time, expected_count, count);
        error_count <= error_count + 1;
    end else begin
        $display("Match at time %0t: Expected count = %b, Actual count = %b", $time, expected_count, count);
        $fdisplay(file,"Match at time %0t: Expected count = %b, Actual count = %b", $time, expected_count, count);
    end
endtask


endmodule
