`timescale 1ns/1ps
// Reset synchronizer: asynchronous assertion, synchronous deassertion.
//   i_rst_n (active low) may change at any time, e.g. a board button or
//   "button AND MMCM locked". o_rst_n goes low at once, without a clock, and
//   goes high on the STAGES-th rising edge of i_clk after i_rst_n rises. All
//   flip-flops that use o_rst_n then leave reset in the same cycle, and the
//   release edge is synchronous to i_clk (no recovery/removal violation).
// Users: modules with an asynchronous reset (posedge clk or negedge rst_n)
//   and modules with a synchronous reset (posedge clk, if (!rst_n)) can share
//   o_rst_n. Even an i_rst_n pulse shorter than a clock period keeps o_rst_n
//   low on at least STAGES-1 rising edges, so synchronous users see it.
// The flip-flops carry ASYNC_REG so that Vivado places them together and
//   treats them as a synchronizer.
module reset_sync #(
    parameter integer STAGES = 2        // at least 2
) (
    input  wire i_clk,
    input  wire i_rst_n,                // asynchronous, active low
    output wire o_rst_n                 // asynchronous assert, synchronous deassert
);
    generate
        if (STAGES < 2) begin : g_bad_stages
            reset_sync_STAGES_must_be_at_least_2 u_error ();
        end
    endgenerate

    (* ASYNC_REG = "TRUE" *) reg [STAGES-1:0] r_sync;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) r_sync <= {STAGES{1'b0}};
        else r_sync <= {r_sync[STAGES-2:0], 1'b1};
    end

    assign o_rst_n = r_sync[STAGES-1];
endmodule
