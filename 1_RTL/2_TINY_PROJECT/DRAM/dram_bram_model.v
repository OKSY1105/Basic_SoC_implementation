`timescale 1ns / 1ps
`default_nettype none
// Synthesizable DRAM model for the FPGA board: the pins and the command and
// latency rules of the behavioral model dram.v, with the array in block RAM
// and every register on the system clock i_clk.
//
// Use: next to dram_controller_core inside the FPGA (no tri-state). Connect
// the core's o_dram_dq to i_dq, o_dq to the core's i_dram_dq, and the core's
// o_dram_dqs_t/o_dram_dqs_c to i_dqs_t/i_dqs_c. CK must be the core's model
// clock i_clk / 4 (two i_clk cycles high, two low), made from this i_clk.
//
// How the pins are seen (one i_clk after dram.v sees the same edge):
//   - CK rising edge: i_ck_t = 1 while its previous i_clk sample is 0 (the
//     first i_clk cycle of CK high). The command pins are stable then (the
//     core changes them a quarter CK before the rising edge). The state
//     updates at the end of that cycle with dram.v's rules.
//   - DQS rising edge: the same detection on i_dqs_c and i_dqs_t. The write
//     byte on DQ is taken at the end of that cycle (the core changes DQ a
//     quarter CK after the DQS edge). Byte placement follows dram.v.
//   - Read: DQ is driven while dram.v's count is CL..CL+3. In the first i_clk
//     cycle of CK high that count is cnt + 1, because cnt is updated at the
//     end of that cycle. Byte 2k while CK is high, byte 2k+1 while CK is low;
//     the core samples a quarter CK after each CK edge.
// Same as dram.v: commands {csn, actn, a[16:14]} ACT/RD/WR/MRS, row = a[3:0]
// at ACT, column = a[3:0] at RD/WR, CL 9/10 by MR0 and CWL 10/11 by MR2, one
// 64-bit word per {row, column} (16 x 16 words = 2 KiB), the array write two
// CK edges after the last write byte, no reset input, no PRE/REF/bank, no
// error. Different from dram.v: no read DQS output (the core has no DQS
// input), DQ split into i_dq and o_dq/o_dq_oe, power-up values for the state
// registers and the array (zero), ck_c and cke unused.
// Simulation: the DRAM controller TBs use this model instead of dram.v when
// compiled with -d DRAM_BRAM_MODEL. They read the same internal names as in
// dram.v (tCL, tCWL, read_op, dq_oe, data_write, mem); the array is
// mem[{row, column}] here instead of dram.v's mem[row][column].
module dram_bram_model (
    input  wire        i_clk,
    input  wire        i_ck_t,
    input  wire        i_ck_c,            // unused
    input  wire        i_cke,             // unused (dram.v ignores it too)
    input  wire        i_csn,
    input  wire        i_actn,
    input  wire [1:0]  i_bg,
    input  wire [1:0]  i_ba,
    input  wire [17:0] i_a,               // rasn 16, casn 15, wen 14
    input  wire [7:0]  i_dq,
    output reg  [7:0]  o_dq,
    output wire        o_dq_oe,
    input  wire        i_dqs_t,
    input  wire        i_dqs_c
);
    localparam [4:0] ACT = 5'b00111, WR = 5'b01100, RD = 5'b01101, MRS = 5'b01000;

    wire [4:0] opcode = {i_csn, i_actn, i_a[16], i_a[15], i_a[14]};

    // Power-up values (FPGA configuration). Like a DRAM device, no reset.
    reg        r_ck = 1'b0, r_dqs_t = 1'b0, r_dqs_c = 1'b0;
    reg [3:0]  tCL = 4'd0, tCWL = 4'd0;
    reg [3:0]  row = 4'd0, col = 4'd0;
    reg        write_op = 1'b0, read_op = 1'b0, data_write = 1'b0;
    reg [4:0]  cnt = 5'd0;
    reg [63:0] curr_data = 64'd0;
    reg [63:0] read_data = 64'd0;
    // One dimension, word {row, column}: a two-dimensional array (as in
    // dram.v) is split into registers by Vivado synthesis, not block RAM.
    (* ram_style = "block" *) reg [63:0] mem [0:255];
    wire [7:0] addr = {row, col};
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 64'd0;

    wire ck_rise    = i_ck_t  & ~r_ck;
    wire dqs_t_rise = i_dqs_t & ~r_dqs_t;
    wire dqs_c_rise = i_dqs_c & ~r_dqs_c;

    always @(posedge i_clk) begin
        r_ck    <= i_ck_t;
        r_dqs_t <= i_dqs_t;
        r_dqs_c <= i_dqs_c;
    end

    // dram.v's posedge ck_t blocks, on the detected CK rising edge.
    always @(posedge i_clk) if (ck_rise) begin
        case (opcode)
            ACT:     row <= i_a[3:0];
            WR, RD:  col <= i_a[3:0];
            default: ;
        endcase

             if (opcode == ACT)  write_op <= 1'b0;
        else if (opcode == WR)   write_op <= 1'b1;
        else if (cnt == tCWL+4)  write_op <= 1'b0;

             if (opcode == ACT)  read_op <= 1'b0;
        else if (opcode == RD)   read_op <= 1'b1;
        else if (cnt == tCL+4)   read_op <= 1'b0;

             if (opcode == ACT)               cnt <= 5'd0;
        else if (opcode == WR || opcode == RD) cnt <= 5'd1;
        else if (write_op) cnt <= (cnt == tCWL+4) ? 5'd0 : cnt + 5'd1;
        else if (read_op)  cnt <= (cnt == tCL +4) ? 5'd0 : cnt + 5'd1;

        data_write <= write_op && (cnt == tCWL+4);

        if (opcode == MRS) begin
            if ({i_bg[0], i_ba} == 3'd0)
                tCL  <= ({i_a[6:4], i_a[2]} == 4'b0001) ? 4'd10 : 4'd9;
            else if ({i_bg[0], i_ba} == 3'd2)
                tCWL <= (i_a[5:3] == 3'b010) ? 4'd11 : 4'd10;
        end
    end

    // Block RAM: one write port (the commit) and one registered read port,
    // both at {row, column}.
    always @(posedge i_clk) begin
        if (ck_rise && data_write) mem[addr] <= curr_data;
        read_data <= mem[addr];
    end

    // Write data on the DQS rising edges (dram.v's posedge dqs_c / dqs_t).
    always @(posedge i_clk) begin
        if (dqs_c_rise) begin
                 if (cnt == tCWL)   curr_data[ 7: 0] <= i_dq;
            else if (cnt == tCWL+1) curr_data[23:16] <= i_dq;
            else if (cnt == tCWL+2) curr_data[39:32] <= i_dq;
            else if (cnt == tCWL+3) curr_data[55:48] <= i_dq;
        end
        if (dqs_t_rise) begin
                 if (cnt == tCWL)   curr_data[15: 8] <= i_dq;
            else if (cnt == tCWL+1) curr_data[31:24] <= i_dq;
            else if (cnt == tCWL+2) curr_data[47:40] <= i_dq;
            else if (cnt == tCWL+3) curr_data[63:56] <= i_dq;
        end
    end

    // Read DQ (dram.v's dq_oe and dq_o windows).
    wire [4:0] cnt_ck = ck_rise ? cnt + 5'd1 : cnt;   // dram.v's count in this CK cycle
    wire [4:0] beat   = cnt_ck - {1'b0, tCL};
    wire       dq_oe  = read_op && (cnt_ck >= tCL) && (cnt_ck <= tCL+3);
    assign o_dq_oe = dq_oe;

    always @* begin
        case (beat)
            5'd0:    o_dq = i_ck_t ? read_data[ 7: 0] : read_data[15: 8];
            5'd1:    o_dq = i_ck_t ? read_data[23:16] : read_data[31:24];
            5'd2:    o_dq = i_ck_t ? read_data[39:32] : read_data[47:40];
            5'd3:    o_dq = i_ck_t ? read_data[55:48] : read_data[63:56];
            default: o_dq = 8'h00;
        endcase
    end
endmodule
`default_nettype wire
