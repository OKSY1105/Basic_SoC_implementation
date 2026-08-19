`timescale 1ns / 1ps
module adder
(
     // Port Declarations
    // ==========================================
    // Half Adder
    i_half_a,
    i_half_b,
    o_half_sum,
    o_half_carry,

    // Full Adder
    i_full_a,
    i_full_b,
    i_full_carry,
    o_full_sum,
    o_full_carry,

    // BCD Adder
    i_bcd_a,
    i_bcd_b,
    i_bcd_carry,
    o_bcd_sum,
    o_bcd_carry
);

    // ==========================================
    // Input/Output Definitions
    // ==========================================
    // Half Adder
    input        i_half_a;
    input        i_half_b;
    output       o_half_sum;
    output       o_half_carry;

    // Full Adder
    input        i_full_a;
    input        i_full_b;
    input        i_full_carry;
    output       o_full_sum;
    output       o_full_carry;

    // BCD Adder
    input  [3:0] i_bcd_a;
    input  [3:0] i_bcd_b;
    input        i_bcd_carry;
    output [3:0] o_bcd_sum;
    output       o_bcd_carry;

    // ==========================================
    // Logic Implementation
    // ==========================================
    //====== Half Adder ===============
    assign o_half_sum = i_half_a ^ i_half_b;
    assign o_half_carry = i_half_a & i_half_b;

    //====== Full Adder ===============
    assign o_full_sum = i_full_a ^ i_full_b ^ i_full_carry;
    assign o_full_carry = (i_full_a & i_full_b) | (i_full_b &i_full_carry) | (i_full_a &i_full_carry);

    //====== BCD Adder ================
    wire [4:0] sum;
     
    assign sum = i_bcd_a + i_bcd_b + i_bcd_carry;
    assign o_bcd_sum = sum > 5'd9 ? sum+4'd6 : sum;
    assign o_bcd_carry = sum > 5'd9 ? 1 : 0 ;

endmodule
