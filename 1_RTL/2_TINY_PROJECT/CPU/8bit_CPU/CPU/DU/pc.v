`timescale 1ns/1ps
// Adapted from the author's 8-bit counter.v (enable, hold and branch/jump load added).
// Byte-addressed PC; sequential instruction length = 2 bytes.
module pc (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire       i_en,
    input  wire       i_load,
    input  wire [7:0] i_load_addr,
    output reg  [7:0] o_pc
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            o_pc <= 8'h00;
        else if (i_en) begin
            if (i_load)
                o_pc <= i_load_addr;
            else
                o_pc <= o_pc + 8'd2;
        end
    end
endmodule
