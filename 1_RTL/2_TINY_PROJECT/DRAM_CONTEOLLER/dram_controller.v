`timescale 1ns / 1ps

// Byte/line-access controller for ../DRAM/dram.v (the project's behavioral
// model). This is NOT a physical DDR PHY or a JEDEC-complete memory controller.
//
// Two modules:
//   dram_controller_core: the controller with DQ/DQS split into output,
//     output enable and input (no tri-state), for a memory inside the FPGA.
//   dram_controller: the same controller with inout DQ/DQS (tri-state
//     buffers only), for the behavioral model ../DRAM/dram.v.
//
// Host contract:
//   * One outstanding request. Hold req/line/address/write/wdata until ready.
//   * req && ready at posedge i_clk completes the operation exactly once.
//   * ready lasts one i_clk cycle; a new request is accepted in a later IDLE.
//   * Local address = {row[3:0], column[3:0], byte_offset[2:0]} (2 KiB).
//   * i_line=0 (byte): offset 0 selects bits [7:0]; byte writes use
//     read-modify-write (RMW: one RD burst, then one WR burst).
//   * i_line=1 (line): one 64-bit line = one BL8 burst at address [10:3]
//     (offset ignored); byte k is bits [8k+7:8k]. A line read is one RD and
//     returns o_line_rdata with ready; a line write is one WR of i_line_wdata
//     (no RMW read). This is the port of the data cache.
//   * error is always 0: this model has no error response or timeout input.
//
// Clock/timing contract:
//   i_clk is the host/controller clock; generated model CK is i_clk / 4.
//   A future physical DRAM interface requires its own PHY/clock constraints.
//   Commands are set up a quarter cycle before the model CK rising edge.
//   Read DQ is sampled a quarter cycle after each model CK transition.
//   Write DQ is set up one i_clk before the corresponding DQS rising edge.
//   CL supports 9/10 and CWL supports 10/11, as encoded by the existing model.
//
// Synchronous active-low reset:
//   Before a RD/WR is scheduled, reset cancels the request immediately.
//   Once RD is scheduled, its burst drains and any subsequent WR is cancelled.
//   Once WR is scheduled, the ENTIRE latched RMW burst is completed, including
//   the model's delayed array commit, even while reset is held low. No host
//   completion is emitted for a cancelled request. CK therefore keeps running
//   during this drain. MRS/ACT initialization runs again after reset release.
//   Reset does not clear the DRAM array, and does not undo an issued write.
//
// No PRE/REF, refresh, bank scheduling, training, or real-board constraints.
// Read data is captured at fixed phases of the generated CK, so the core has
// no DQS input.
module dram_controller_core #(
    parameter integer T_RCD_CYCLES = 9,
    parameter integer CL_CYCLES = 9,
    parameter integer CWL_CYCLES = 10
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_req,
    input  wire        i_write,
    input  wire        i_line,
    input  wire [10:0] i_addr,
    input  wire [7:0]  i_wdata,
    input  wire [63:0] i_line_wdata,
    output wire        o_ready,
    output wire [7:0]  o_rdata,
    output wire [63:0] o_line_rdata,
    output wire        o_error,
    output wire        o_busy,
    output reg         o_initialized,

    output reg         o_dram_ck_t,
    output wire        o_dram_ck_c,
    output wire        o_dram_cke,
    output reg         o_dram_csn,
    output reg         o_dram_actn,
    output reg  [1:0]  o_dram_bg,
    output reg  [1:0]  o_dram_ba,
    output reg  [17:0] o_dram_a,
    output wire [7:0]  o_dram_dq,
    output wire        o_dram_dq_oe,
    input  wire [7:0]  i_dram_dq,
    output wire        o_dram_dqs_t,
    output wire        o_dram_dqs_c,
    output wire        o_dram_dqs_oe
);
    localparam [3:0] ST_POWERUP = 0, ST_MRS0_WAIT = 1,
                     ST_MRS2_WAIT = 2, ST_INIT_WAIT = 3,
                     ST_IDLE = 4, ST_READ_ACT = 5, ST_READ_RCD = 6,
                     ST_READ = 7, ST_MERGE = 8, ST_WRITE_ACT = 9,
                     ST_WRITE_RCD = 10, ST_WRITE = 11, ST_DONE = 12;

    reg [3:0]  r_state;
    reg [1:0]  r_phase;
    reg [15:0] r_wait;
    reg [15:0] r_cycle;
    reg        r_write;
    reg [10:0] r_addr;
    reg [7:0]  r_wdata;
    reg [63:0] r_burst;
    reg [7:0]  r_response;
    reg        r_cancel;
    reg [7:0]  r_dq;
    reg        r_dq_oe;
    reg        r_dqs_oe;
    reg        r_dqs_t;
    reg        r_dqs_c;
    reg        w_transfer_active;

    // A case default also allows the very first synchronous reset to recover
    // from simulator X state without relying on FPGA-only initial values.
    always @* begin
        w_transfer_active = 1'b0;
        case (r_state)
            ST_READ, ST_WRITE: w_transfer_active = 1'b1;
            default: w_transfer_active = 1'b0;
        endcase
    end

    assign o_dram_ck_c = ~o_dram_ck_t;
    assign o_dram_cke = 1'b1;
    assign o_dram_dq = r_dq;
    assign o_dram_dq_oe = r_dq_oe;
    assign o_dram_dqs_t = r_dqs_t;
    assign o_dram_dqs_c = r_dqs_c;
    assign o_dram_dqs_oe = r_dqs_oe;
    assign o_ready = i_rst_n && !r_cancel && (r_state == ST_DONE);
    assign o_rdata = r_response;
    // The whole burst: read data of a line read, valid with o_ready.
    assign o_line_rdata = r_burst;
    assign o_error = 1'b0;
    assign o_busy = !o_initialized || (r_state != ST_IDLE);

    always @(posedge i_clk) begin
        if (!i_rst_n && !w_transfer_active) begin
            r_state <= ST_POWERUP;
            r_phase <= 0;
            r_wait <= 0;
            r_cycle <= 0;
            r_write <= 0;
            r_addr <= 0;
            r_wdata <= 0;
            r_burst <= 0;
            r_response <= 0;
            r_cancel <= 0;
            r_dq <= 0;
            r_dq_oe <= 0;
            r_dqs_oe <= 0;
            r_dqs_t <= 0;
            r_dqs_c <= 0;
            o_initialized <= 0;
            o_dram_ck_t <= 0;
            o_dram_csn <= 1;
            o_dram_actn <= 1;
            o_dram_bg <= 0;
            o_dram_ba <= 0;
            o_dram_a <= 0;
        end else begin
            r_phase <= r_phase + 1'b1;
            if (r_phase == 0) o_dram_ck_t <= 1;
            if (r_phase == 2) o_dram_ck_t <= 0;

            if (!i_rst_n) begin
                r_cancel <= 1;
                r_response <= 0;
                o_initialized <= 0;
            end

            // Count model CK rising edges since the scheduled RD/WR.
            if (w_transfer_active && r_phase == 0)
                r_cycle <= r_cycle + 1'b1;

            if (r_state == ST_READ &&
                r_cycle >= CL_CYCLES && r_cycle < CL_CYCLES + 4) begin
                if (r_phase == 1)
                    r_burst[(r_cycle-CL_CYCLES)*16 +: 8] <= i_dram_dq;
                if (r_phase == 3)
                    r_burst[(r_cycle-CL_CYCLES)*16+8 +: 8] <= i_dram_dq;
            end

            if (r_state == ST_WRITE) begin
                if (r_phase == 0) begin
                    r_dqs_t <= 0;
                    r_dqs_c <= 0;
                    if (r_cycle+1 >= CWL_CYCLES &&
                        r_cycle+1 < CWL_CYCLES+4) begin
                        r_dq_oe <= 1;
                        r_dqs_oe <= 1;
                        r_dq <= r_burst[(r_cycle+1-CWL_CYCLES)*16 +: 8];
                    end else begin
                        r_dq_oe <= 0;
                        // Hold both DQS drivers low through this CK edge.
                        // Releasing 0 -> Z is a Verilog posedge; releasing
                        // here races the model's NBA update of cnt and can
                        // overwrite its last even byte with high impedance.
                    end
                end
                if (r_phase == 1 && r_cycle >= CWL_CYCLES+4)
                    r_dqs_oe <= 0;
                if (r_cycle >= CWL_CYCLES && r_cycle < CWL_CYCLES+4) begin
                    if (r_phase == 1) r_dqs_c <= 1;
                    if (r_phase == 2) begin
                        r_dqs_t <= 0;
                        r_dqs_c <= 0;
                        r_dq <= r_burst[(r_cycle-CWL_CYCLES)*16+8 +: 8];
                    end
                    if (r_phase == 3) r_dqs_t <= 1;
                end
            end

            // Default NOP, with command setup before the next CK rising edge.
            if (r_phase == 3) begin
                o_dram_csn <= 1;
                o_dram_actn <= 1;
                o_dram_bg <= 0;
                o_dram_ba <= 0;
                o_dram_a <= 0;
            end

            case (r_state)
                ST_POWERUP: if (r_phase == 3) begin
                    // MR0: {A[6:4], A[2]} == 0001 selects CL=10, else 9.
                    o_dram_csn <= 0;
                    o_dram_actn <= 1;
                    o_dram_a <= (CL_CYCLES == 10) ? 18'h00004 : 18'h00000;
                    r_cancel <= 0;
                    r_wait <= 2;
                    r_state <= ST_MRS0_WAIT;
                end
                ST_MRS0_WAIT: if (r_phase == 3) begin
                    if (r_wait != 0) r_wait <= r_wait - 1'b1;
                    else begin
                        // MR2: A[5:3] == 010 selects CWL=11, else 10.
                        o_dram_csn <= 0;
                        o_dram_actn <= 1;
                        o_dram_ba <= 2;
                        o_dram_a <= (CWL_CYCLES == 11) ? 18'h00010 : 18'h00000;
                        r_wait <= 2;
                        r_state <= ST_MRS2_WAIT;
                    end
                end
                ST_MRS2_WAIT: if (r_phase == 3) begin
                    if (r_wait != 0) r_wait <= r_wait - 1'b1;
                    else begin
                        // ACT clears the model's uninitialized operation flags
                        // and counter. It does not initialize its memory array.
                        o_dram_csn <= 0;
                        o_dram_actn <= 0;
                        o_dram_a <= 18'h1c000;
                        r_wait <= 2;
                        r_state <= ST_INIT_WAIT;
                    end
                end
                ST_INIT_WAIT: if (r_phase == 3) begin
                    if (r_wait != 0) r_wait <= r_wait - 1'b1;
                    else begin
                        o_initialized <= 1;
                        r_state <= ST_IDLE;
                    end
                end
                ST_IDLE: if (i_req) begin
                    r_write <= i_write;
                    r_addr <= i_addr;
                    r_wdata <= i_wdata;
                    r_response <= 0;
                    // A line write has its whole burst already: no RMW read.
                    // A line read is a plain read; so after a RD burst
                    // r_write still means "byte write, merge next".
                    if (i_line && i_write) begin
                        r_burst <= i_line_wdata;
                        r_state <= ST_WRITE_ACT;
                    end else begin
                        r_state <= ST_READ_ACT;
                    end
                end
                ST_READ_ACT, ST_WRITE_ACT: if (r_phase == 3) begin
                    o_dram_csn <= 0;
                    o_dram_actn <= 0;
                    o_dram_a <= 18'h1c000 | {14'b0, r_addr[10:7]};
                    r_wait <= T_RCD_CYCLES - 1;
                    r_state <= (r_state == ST_READ_ACT) ? ST_READ_RCD : ST_WRITE_RCD;
                end
                ST_READ_RCD, ST_WRITE_RCD: if (r_phase == 3) begin
                    if (r_wait != 0) r_wait <= r_wait - 1'b1;
                    else begin
                        o_dram_csn <= 0;
                        o_dram_actn <= 1;
                        o_dram_a <= ((r_state == ST_READ_RCD) ?
                                      18'h14000 : 18'h10000) |
                                    {14'b0, r_addr[6:3]};
                        r_cycle <= 0;
                        r_state <= (r_state == ST_READ_RCD) ? ST_READ : ST_WRITE;
                    end
                end
                ST_READ: if (r_phase == 3 && r_cycle == CL_CYCLES+5) begin
                    // read_op and DQS are now quiescent in the existing model.
                    if (r_cancel || !i_rst_n) r_state <= ST_POWERUP;
                    else if (r_write) r_state <= ST_MERGE;
                    else begin
                        r_response <= r_burst[r_addr[2:0]*8 +: 8];
                        r_state <= ST_DONE;
                    end
                end
                ST_MERGE: begin
                    r_burst[r_addr[2:0]*8 +: 8] <= r_wdata;
                    r_state <= ST_WRITE_ACT;
                end
                ST_WRITE: if (r_phase == 3 && r_cycle == CWL_CYCLES+7) begin
                    // The model commits mem[] two CK edges after data_write
                    // preparation. Wait through that delayed commit, too.
                    r_dq_oe <= 0;
                    r_dqs_oe <= 0;
                    if (r_cancel || !i_rst_n) r_state <= ST_POWERUP;
                    else r_state <= ST_DONE;
                end
                ST_DONE: r_state <= ST_IDLE;
                default: r_state <= ST_POWERUP;
            endcase
        end
    end
endmodule

// dram_controller_core with inout DQ/DQS for the behavioral model dram.v.
// The tri-state drivers follow the core's output enables exactly.
module dram_controller #(
    parameter integer T_RCD_CYCLES = 9,
    parameter integer CL_CYCLES = 9,
    parameter integer CWL_CYCLES = 10
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_req,
    input  wire        i_write,
    input  wire        i_line,
    input  wire [10:0] i_addr,
    input  wire [7:0]  i_wdata,
    input  wire [63:0] i_line_wdata,
    output wire        o_ready,
    output wire [7:0]  o_rdata,
    output wire [63:0] o_line_rdata,
    output wire        o_error,
    output wire        o_busy,
    output wire        o_initialized,

    output wire        o_dram_ck_t,
    output wire        o_dram_ck_c,
    output wire        o_dram_cke,
    output wire        o_dram_csn,
    output wire        o_dram_actn,
    output wire [1:0]  o_dram_bg,
    output wire [1:0]  o_dram_ba,
    output wire [17:0] o_dram_a,
    inout  wire [7:0]  io_dram_dq,
    inout  wire        io_dram_dqs_t,
    inout  wire        io_dram_dqs_c
);
    wire [7:0] w_dq;
    wire w_dq_oe, w_dqs_t, w_dqs_c, w_dqs_oe;

    dram_controller_core #(
        .T_RCD_CYCLES(T_RCD_CYCLES), .CL_CYCLES(CL_CYCLES), .CWL_CYCLES(CWL_CYCLES)
    ) u_core (
        .i_clk(i_clk), .i_rst_n(i_rst_n), .i_req(i_req), .i_write(i_write),
        .i_line(i_line), .i_addr(i_addr), .i_wdata(i_wdata), .i_line_wdata(i_line_wdata),
        .o_ready(o_ready), .o_rdata(o_rdata), .o_line_rdata(o_line_rdata),
        .o_error(o_error), .o_busy(o_busy), .o_initialized(o_initialized),
        .o_dram_ck_t(o_dram_ck_t), .o_dram_ck_c(o_dram_ck_c), .o_dram_cke(o_dram_cke),
        .o_dram_csn(o_dram_csn), .o_dram_actn(o_dram_actn), .o_dram_bg(o_dram_bg),
        .o_dram_ba(o_dram_ba), .o_dram_a(o_dram_a),
        .o_dram_dq(w_dq), .o_dram_dq_oe(w_dq_oe), .i_dram_dq(io_dram_dq),
        .o_dram_dqs_t(w_dqs_t), .o_dram_dqs_c(w_dqs_c), .o_dram_dqs_oe(w_dqs_oe)
    );

    assign io_dram_dq = w_dq_oe ? w_dq : 8'bz;
    assign io_dram_dqs_t = w_dqs_oe ? w_dqs_t : 1'bz;
    assign io_dram_dqs_c = w_dqs_oe ? w_dqs_c : 1'bz;
endmodule
