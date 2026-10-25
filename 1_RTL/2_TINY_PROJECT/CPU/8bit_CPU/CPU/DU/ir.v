`timescale 1ns/1ps
// Adapted from the author's 16-bit register byte-enable example.
// Fetch order: high byte at PC, low byte at PC+1 (big-endian instruction bytes).
module ir (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire       i_hi_we,
    input  wire       i_lo_we,
    input  wire [7:0] i_data,
    output reg  [15:0] o_instruction
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            o_instruction <= 16'h0000;
        else begin
            if (i_hi_we) o_instruction[15:8] <= i_data;
            if (i_lo_we) o_instruction[7:0]  <= i_data;
        end
    end
endmodule
