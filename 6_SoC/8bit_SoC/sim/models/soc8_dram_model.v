`timescale 1ns/1ps
// Simulation memory for soc8_top: the behavioral DRAM model dram.v
// (1_RTL/2_TINY_PROJECT/DRAM) on the DRAM controller core's split pins.
// The tri-state drivers follow the core's output enables exactly, as in the
// dram_controller wrapper; the model drives DQ/DQS when the core does not.
// The board uses the BRAM-based synthesizable model (M4) instead.
module soc8_dram_model (
    input  wire        i_ck_t,
    input  wire        i_ck_c,
    input  wire        i_cke,
    input  wire        i_csn,
    input  wire        i_actn,
    input  wire [1:0]  i_bg,
    input  wire [1:0]  i_ba,
    input  wire [17:0] i_a,
    input  wire [7:0]  i_dq,                      // controller DQ output
    input  wire        i_dq_oe,
    output wire [7:0]  o_dq,                      // to the controller DQ input
    input  wire        i_dqs_t,
    input  wire        i_dqs_c,
    input  wire        i_dqs_oe
);
    tri [7:0] w_dq;
    tri       w_dqs_t, w_dqs_c;

    assign w_dq    = i_dq_oe  ? i_dq    : 8'bz;
    assign w_dqs_t = i_dqs_oe ? i_dqs_t : 1'bz;
    assign w_dqs_c = i_dqs_oe ? i_dqs_c : 1'bz;
    assign o_dq    = w_dq;

    dram u_dram (
        .ck_t(i_ck_t), .ck_c(i_ck_c), .cke(i_cke), .csn(i_csn), .actn(i_actn),
        .bg(i_bg), .ba(i_ba), .a(i_a), .dq(w_dq), .dqs_t(w_dqs_t), .dqs_c(w_dqs_c));
endmodule
