`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations
    // ==========================================
    // Half Adder
    reg        i_half_a;
    reg        i_half_b;
    wire       o_half_sum;
    wire       o_half_carry;

    // Full Adder
    reg        i_full_a;
    reg        i_full_b;
    reg        i_full_carry;
    wire       o_full_sum;
    wire       o_full_carry;

    // BCD Adder
    reg  [3:0] i_bcd_a;
    reg  [3:0] i_bcd_b;
    reg        i_bcd_carry;
    wire [3:0] o_bcd_sum;
    wire       o_bcd_carry;

    integer file;

    // ==========================================
    // Module Instantiation
    // ==========================================
    adder u_adder (
        // Half Adder
        .i_half_a     ( i_half_a     ),
        .i_half_b     ( i_half_b     ),
        .o_half_sum   ( o_half_sum   ),
        .o_half_carry ( o_half_carry ),

        // Full Adder
        .i_full_a     ( i_full_a     ),
        .i_full_b     ( i_full_b     ),
        .i_full_carry ( i_full_carry ),
        .o_full_sum   ( o_full_sum   ),
        .o_full_carry ( o_full_carry ),

        // BCD Adder
        .i_bcd_a      ( i_bcd_a      ),
        .i_bcd_b      ( i_bcd_b      ),
        .i_bcd_carry  ( i_bcd_carry  ),
        .o_bcd_sum    ( o_bcd_sum    ),
        .o_bcd_carry  ( o_bcd_carry  )
    );

    // ==========================================
    // Test Sequence
    // ==========================================
    initial begin
        file = $fopen("output.txt", "w");

        // --------------------------------------
        // Half Adder Test
        // --------------------------------------
        $fdisplay(file, "=== Half Adder Test ===");
        
        i_half_a = 0; i_half_b = 0; #10;
        $fdisplay(file, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", i_half_a, i_half_b, o_half_sum, o_half_carry);
        
        i_half_a = 0; i_half_b = 1; #10;
        $fdisplay(file, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", i_half_a, i_half_b, o_half_sum, o_half_carry);
        
        i_half_a = 1; i_half_b = 0; #10;
        $fdisplay(file, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", i_half_a, i_half_b, o_half_sum, o_half_carry);
        
        i_half_a = 1; i_half_b = 1; #10;
        $fdisplay(file, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", i_half_a, i_half_b, o_half_sum, o_half_carry);

        // --------------------------------------
        // Full Adder Test
        // --------------------------------------
        $fdisplay(file, "\n=== Full Adder Test ===");
        
        i_full_a = 0; i_full_b = 0; i_full_carry = 0; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 0; i_full_b = 1; i_full_carry = 0; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 1; i_full_b = 0; i_full_carry = 0; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 1; i_full_b = 1; i_full_carry = 0; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 0; i_full_b = 0; i_full_carry = 1; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 0; i_full_b = 1; i_full_carry = 1; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 1; i_full_b = 0; i_full_carry = 1; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);
        
        i_full_a = 1; i_full_b = 1; i_full_carry = 1; #10;
        $fdisplay(file, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", i_full_a, i_full_b, i_full_carry, o_full_sum, o_full_carry);

        // --------------------------------------
        // BCD Adder Test
        // --------------------------------------
        $fdisplay(file, "\n=== BCD Adder Test ===");
        
        i_bcd_a = 4'd2; i_bcd_b = 4'd3; i_bcd_carry = 0; #10; // 2 + 3 = 5
        $fdisplay(file, "i_bcd_a = %d, i_bcd_b = %d, i_bcd_carry = %b -> o_bcd_sum = %d, o_bcd_carry = %b", i_bcd_a, i_bcd_b, i_bcd_carry, o_bcd_sum, o_bcd_carry);
        
        i_bcd_a = 4'd5; i_bcd_b = 4'd5; i_bcd_carry = 0; #10; // 5 + 5 = 10 (보정 필요)
        $fdisplay(file, "i_bcd_a = %d, i_bcd_b = %d, i_bcd_carry = %b -> o_bcd_sum = %d, o_bcd_carry = %b", i_bcd_a, i_bcd_b, i_bcd_carry, o_bcd_sum, o_bcd_carry);
        
        i_bcd_a = 4'd8; i_bcd_b = 4'd7; i_bcd_carry = 0; #10; // 8 + 7 = 15 (보정 필요)
        $fdisplay(file, "i_bcd_a = %d, i_bcd_b = %d, i_bcd_carry = %b -> o_bcd_sum = %d, o_bcd_carry = %b", i_bcd_a, i_bcd_b, i_bcd_carry, o_bcd_sum, o_bcd_carry);
        
        i_bcd_a = 4'd9; i_bcd_b = 4'd9; i_bcd_carry = 1; #10; // 9 + 9 + 1 = 19 (보정 필요)
        $fdisplay(file, "i_bcd_a = %d, i_bcd_b = %d, i_bcd_carry = %b -> o_bcd_sum = %d, o_bcd_carry = %b", i_bcd_a, i_bcd_b, i_bcd_carry, o_bcd_sum, o_bcd_carry);

        $fclose(file);
        $finish;
    end

endmodule