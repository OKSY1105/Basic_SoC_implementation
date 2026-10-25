`timescale 1ns/1ps
// Based on the author's filp_flop.v: synchronous 8-bit data storage.
// Modified to form a 2-read/1-write bank of 8 registers.
// R0 is hardwired to 0 (MIPS-style).
module irf (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire [2:0] i_ra,
    input  wire [2:0] i_rb,
    input  wire [2:0] i_wa,
    input  wire [7:0] i_wdata,
    input  wire       i_we,
    output wire [7:0] o_a,
    output wire [7:0] o_b
);
    reg [7:0] r_regs [0:7];
    integer k;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (k = 0; k < 8; k = k + 1)
                r_regs[k] <= 8'h00;
        end else if (i_we && (i_wa != 3'd0)) begin
            r_regs[i_wa] <= i_wdata;
        end
    end

    assign o_a = (i_ra == 3'd0) ? 8'h00 : r_regs[i_ra];
    assign o_b = (i_rb == 3'd0) ? 8'h00 : r_regs[i_rb];
endmodule
