`timescale 1ns / 1ps
// Line-port test for dram_controller with the behavioral model ../DRAM/dram.v.
// Compile this file, dram_controller.v and ../DRAM/dram.v (or, with
// -d DRAM_BRAM_MODEL, ../DRAM/dram_bram_model.v: the board model). With
// both models and -d DRAM_MODEL_MATCH, the board model also runs beside
// dram.v and is compared with it (see the DRAM_MODEL_MATCH block).
// Tops: tb_dram_line (CL=9, CWL=10, tRCD=9) and tb_dram_line_alt (10/11/12).
// Reference: 256 lines x 64 bit, preloaded into the model array (as in
// tb_dram_controller) so that every line has a known nonzero value.
// Checks (reference written here, independent of the controller):
//   - A line write commits exactly once in the model (the model array equals
//     the reference) with exactly one WR command and no RD (no RMW).
//   - A line read returns the reference line with one RD and no WR.
//   - Byte reads/writes mixed with line accesses stay consistent.
//   - One completion per request; no completion during reset; no DQ
//     contention between controller and model; DQ/DQS are high impedance
//     unless the core's output enable (or the model) drives them.
//   - Held req: a line write-back followed by a refill whose address changes
//     at the ready edge (the data cache's sequence) completes each once.
//   - Reset: a line write cancelled before WR (no WR, no commit), a line
//     write drained after WR (one commit, no completion), a line read
//     drained (no completion, no change).
// Scenarios: all 256 lines written then read back; 1,500 random mixed
// operations with write-back/refill pairs; the reset cases.
// Prints DRAM_LINE_PASS only if no check failed and every case occurred.
module tb_dram_line #(
    parameter integer T_RCD_CYCLES = 9,
    parameter integer CL_CYCLES = 9,
    parameter integer CWL_CYCLES = 10
);
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0, req = 1'b0, write = 1'b0, line = 1'b0;
    reg [10:0] addr = 11'd0;
    reg [7:0] wdata = 8'd0;
    reg [63:0] lwdata = 64'd0;
    wire ready, error, busy, initialized;
    wire [7:0] rdata;
    wire [63:0] lrdata;
    wire ck_t, ck_c, cke, csn, actn;
    wire [1:0] bg, ba;
    wire [17:0] a;
    tri [7:0] dq;
    tri dqs_t, dqs_c;

    dram_controller #(
        .T_RCD_CYCLES(T_RCD_CYCLES), .CL_CYCLES(CL_CYCLES), .CWL_CYCLES(CWL_CYCLES)
    ) dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_req(req), .i_write(write), .i_line(line),
        .i_addr(addr), .i_wdata(wdata), .i_line_wdata(lwdata),
        .o_ready(ready), .o_rdata(rdata), .o_line_rdata(lrdata),
        .o_error(error), .o_busy(busy), .o_initialized(initialized),
        .o_dram_ck_t(ck_t), .o_dram_ck_c(ck_c), .o_dram_cke(cke),
        .o_dram_csn(csn), .o_dram_actn(actn), .o_dram_bg(bg),
        .o_dram_ba(ba), .o_dram_a(a), .io_dram_dq(dq),
        .io_dram_dqs_t(dqs_t), .io_dram_dqs_c(dqs_c));

`ifdef DRAM_BRAM_MODEL
    // Board model (see tb_dram_controller.v): split DQ on the same net.
    wire [7:0] model_dq;
    wire model_dq_oe;
    dram_bram_model memory_model (
        .i_clk(clk), .i_ck_t(ck_t), .i_ck_c(ck_c), .i_cke(cke), .i_csn(csn),
        .i_actn(actn), .i_bg(bg), .i_ba(ba), .i_a(a), .i_dq(dq),
        .o_dq(model_dq), .o_dq_oe(model_dq_oe), .i_dqs_t(dqs_t), .i_dqs_c(dqs_c));
    assign dq = model_dq_oe ? model_dq : 8'bz;
    `define TBL_MODEL_WORD(r, c) memory_model.mem[(r) * 16 + (c)]   // mem[{row, column}]
`else
    dram memory_model (
        .ck_t(ck_t), .ck_c(ck_c), .cke(cke), .csn(csn), .actn(actn),
        .bg(bg), .ba(ba), .a(a), .dq(dq), .dqs_t(dqs_t), .dqs_c(dqs_c));
    `define TBL_MODEL_WORD(r, c) memory_model.mem[r][c]
`endif

    reg [63:0] ref_line [0:255];
    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // Command and commit monitors (model pins and the model's own commit).
    wire [4:0] opcode = {csn, actn, a[16], a[15], a[14]};
    int unsigned n_rd = 0, n_wr = 0, n_commit = 0, n_done = 0;
    always @(posedge ck_t) begin
        if (opcode == 5'b01101) n_rd++;
        if (opcode == 5'b01100) n_wr++;
        if (memory_model.data_write === 1'b1) n_commit++;
    end
    always @(posedge clk) begin
        if (rst_n && req && ready) n_done++;
        if (!rst_n && ready === 1'b1) fail("completion during reset");
        if (dut.u_core.r_dq_oe === 1'b1 && memory_model.dq_oe === 1'b1) fail("DQ contention");
    end
    // The tri-state wrapper follows the core's output enables exactly: with
    // neither side driving, DQ and DQS are high impedance. (The model has no
    // reset; its enables are X until the first ACT, so only definite 0s count.)
    always @(negedge clk) begin
        if (dut.u_core.r_dq_oe === 1'b0 && memory_model.dq_oe === 1'b0 && dq !== 8'hzz)
            fail($sformatf("DQ driven (%h) without the controller's DQ enable", dq));
        if (dut.u_core.r_dqs_oe === 1'b0 && memory_model.read_op === 1'b0 &&
            (dqs_t !== 1'bz || dqs_c !== 1'bz))
            fail("DQS driven without the controller's DQS enable");
    end

`ifdef DRAM_MODEL_MATCH
    // Side-by-side check (compile dram.v and dram_bram_model.v with
    // -d DRAM_MODEL_MATCH): the board model watches the same pins as dram.v,
    // drives nothing, and must give the same read DQ enable and data in every
    // clock and the same array and CL/CWL at the end.
    wire [7:0] shadow_dq;
    wire shadow_dq_oe;
    dram_bram_model shadow (
        .i_clk(clk), .i_ck_t(ck_t), .i_ck_c(ck_c), .i_cke(cke), .i_csn(csn),
        .i_actn(actn), .i_bg(bg), .i_ba(ba), .i_a(a), .i_dq(dq),
        .o_dq(shadow_dq), .o_dq_oe(shadow_dq_oe), .i_dqs_t(dqs_t), .i_dqs_c(dqs_c));
    int unsigned n_match_clk = 0, n_match_data = 0;
    always @(negedge clk) if (memory_model.dq_oe === 1'b0 || memory_model.dq_oe === 1'b1) begin
        n_match_clk++;
        if (shadow_dq_oe !== memory_model.dq_oe)
            fail($sformatf("board model DQ enable %b, dram.v %b", shadow_dq_oe, memory_model.dq_oe));
        else if (shadow_dq_oe && shadow_dq !== dq)
            fail($sformatf("board model read DQ %h, dram.v %h", shadow_dq, dq));
        else if (shadow_dq_oe) n_match_data++;
    end
    task automatic check_shadow();
        for (int l = 0; l < 256; l++)
            if (shadow.mem[l] !== memory_model.mem[l / 16][l % 16])
                fail($sformatf("board model line %02h = %h, dram.v %h", l,
                     shadow.mem[l], memory_model.mem[l / 16][l % 16]));
        if (shadow.tCL !== memory_model.tCL || shadow.tCWL !== memory_model.tCWL)
            fail("board model CL/CWL differ");
    endtask
`endif

    function automatic logic [63:0] model_line(input logic [7:0] l);
        return `TBL_MODEL_WORD(l[7:4], l[3:0]);
    endfunction

    task automatic check_all_lines(input string what);
        for (int l = 0; l < 256; l++)
            if (model_line(8'(l)) !== ref_line[l])
                fail($sformatf("%s: model line %02h = %h, expected %h", what, l, model_line(8'(l)), ref_line[l]));
    endtask

    task automatic wait_initialized();
        int unsigned t = 0;
        while (initialized !== 1'b1 || busy !== 1'b0) begin
            @(negedge clk); t++;
            if (t > 3000) begin fail("initialization timeout"); return; end
        end
    endtask

    // Latency (negedge count from request to ready) per kind.
    int unsigned lat_min [0:3], lat_max [0:3], lat_n [0:3];
    initial for (int k = 0; k < 4; k++) begin lat_min[k] = 1 << 30; lat_max[k] = 0; lat_n[k] = 0; end

    // One request: kind 0 line read, 1 line write, 2 byte read, 3 byte write.
    task automatic op(input int kind, input logic [10:0] ad, input logic [7:0] bd, input logic [63:0] ld);
        int unsigned rd0, wr0, cm0, dn0, t;
        logic [7:0] l;
        l = ad[10:3];
        @(negedge clk);
        if (busy !== 1'b0 || ready !== 1'b0) fail("request started before idle");
        rd0 = n_rd; wr0 = n_wr; cm0 = n_commit; dn0 = n_done;
        req = 1'b1; line = (kind < 2); write = (kind == 1 || kind == 3);
        addr = ad; wdata = bd; lwdata = ld;
        t = 0;
        while (ready !== 1'b1) begin
            @(negedge clk); t++;
            if (t > 3000) begin fail("request timeout"); req = 1'b0; return; end
        end
        if (t < lat_min[kind]) lat_min[kind] = t;
        if (t > lat_max[kind]) lat_max[kind] = t;
        lat_n[kind]++;
        case (kind)
            0: begin
                if (lrdata !== ref_line[l]) fail($sformatf("line read %02h = %h, expected %h", l, lrdata, ref_line[l]));
                if (n_rd != rd0 + 1 || n_wr != wr0 || n_commit != cm0) fail("line read: commands RD/WR/commit");
            end
            1: begin
                ref_line[l] = ld;
                if (n_rd != rd0 || n_wr != wr0 + 1 || n_commit != cm0 + 1)
                    fail($sformatf("line write: RD+%0d WR+%0d commit+%0d, expected 0/1/1",
                         n_rd - rd0, n_wr - wr0, n_commit - cm0));
                if (model_line(l) !== ld) fail($sformatf("line write %02h not in the model", l));
            end
            2: begin
                if (rdata !== ref_line[l][ad[2:0]*8 +: 8]) fail($sformatf("byte read %03h", ad));
                if (n_rd != rd0 + 1 || n_wr != wr0 || n_commit != cm0) fail("byte read: commands");
            end
            default: begin
                ref_line[l][ad[2:0]*8 +: 8] = bd;
                if (n_rd != rd0 + 1 || n_wr != wr0 + 1 || n_commit != cm0 + 1) fail("byte write: commands (RMW)");
                if (model_line(l) !== ref_line[l]) fail($sformatf("byte write %03h: model line", ad));
            end
        endcase
        @(posedge clk);
        @(negedge clk);
        req = 1'b0;
        if (n_done != dn0 + 1 || ready !== 1'b0) fail("one completion per request");
    endtask

    // Data cache sequence: write back line lw, then refill line lr with req
    // held and the request changed right after the write-back's ready edge.
    int unsigned n_pairs = 0;
    task automatic writeback_refill(input logic [7:0] lw, input logic [63:0] d, input logic [7:0] lr);
        int unsigned dn0, rd0, wr0, t;
        @(negedge clk);
        dn0 = n_done; rd0 = n_rd; wr0 = n_wr;
        req = 1'b1; line = 1'b1; write = 1'b1; addr = {lw, 3'b000}; lwdata = d;
        t = 0;
        while (ready !== 1'b1 && t < 3000) begin @(negedge clk); t++; end
        @(posedge clk); #1;
        ref_line[lw] = d;
        write = 1'b0; addr = {lr, 3'b000};          // as the cache does at the ack edge
        t = 0;
        while (ready !== 1'b1 && t < 3000) begin @(negedge clk); t++; end
        if (lrdata !== ref_line[lr]) fail($sformatf("refill %02h after write-back %02h", lr, lw));
        @(posedge clk); #1 req = 1'b0;
        @(negedge clk);
        if (n_done != dn0 + 2 || n_rd != rd0 + 1 || n_wr != wr0 + 1) fail("write-back/refill pair counts");
        n_pairs++;
    endtask

    // Reset while a line access is in flight.
    int unsigned n_rst_cancel = 0, n_rst_drain = 0, n_rst_read = 0;
    task automatic reset_line_write(input bit after_wr, input int hold, input logic [7:0] l);
        int unsigned dn0, wr0, cm0;
        logic [63:0] d;
        d = ref_line[l] ^ 64'hA5A5_5A5A_F00F_0FF0;
        dn0 = n_done; wr0 = n_wr; cm0 = n_commit;
        @(negedge clk);
        req = 1'b1; line = 1'b1; write = 1'b1; addr = {l, 3'b000}; lwdata = d;
        if (after_wr) begin
            wait (opcode == 5'b01100); @(posedge ck_t);
            repeat (2) @(posedge dqs_c);
        end else begin
            wait (opcode == 5'b00111); @(posedge ck_t);  // ACT of this request
        end
        @(negedge clk);
        rst_n = 1'b0; req = 1'b0;
        repeat (hold) @(negedge clk);
        if (ready !== 1'b0 || initialized !== 1'b0) fail("reset must suppress completion/initialized");
        rst_n = 1'b1;
        wait_initialized();
        if (after_wr) begin
            ref_line[l] = d;
            if (n_done != dn0 || n_commit != cm0 + 1 || n_wr != wr0 + 1)
                fail("line write after WR: must drain once without completion");
            n_rst_drain++;
        end else begin
            if (n_done != dn0 || n_commit != cm0 || n_wr != wr0)
                fail("line write before WR: must be cancelled");
            n_rst_cancel++;
        end
        check_all_lines("after reset");
        op(0, {l, 3'b000}, 8'h00, 64'd0);
    endtask

    task automatic reset_line_read(input logic [7:0] l);
        int unsigned dn0, wr0, cm0;
        dn0 = n_done; wr0 = n_wr; cm0 = n_commit;
        @(negedge clk);
        req = 1'b1; line = 1'b1; write = 1'b0; addr = {l, 3'b000};
        wait (opcode == 5'b01101); @(posedge ck_t);
        @(negedge clk);
        rst_n = 1'b0; req = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        wait_initialized();
        if (n_done != dn0 || n_commit != cm0 || n_wr != wr0) fail("line read during reset: no completion, no write");
        check_all_lines("after read reset");
        n_rst_read++;
    endtask

    initial begin
        int kind;
        logic [10:0] ad;
        // Nonzero known contents (same pattern as tb_dram_controller).
        for (int l = 0; l < 256; l++)
            for (int k = 0; k < 8; k++) begin
                int b;
                b = l * 8 + k;
                ref_line[l][k*8 +: 8] = 8'((b * 37) ^ (b >> 3) ^ (b >> 8) ^ 8'h5a);
            end
        for (int l = 0; l < 256; l++) `TBL_MODEL_WORD(l / 16, l % 16) = ref_line[l];
`ifdef DRAM_MODEL_MATCH
        for (int l = 0; l < 256; l++) shadow.mem[l] = ref_line[l];
`endif

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        wait_initialized();
        check_all_lines("initial");

        // Every line written, then read back; byte access cross-checks.
        for (int l = 0; l < 256; l++)
            op(1, 11'(l * 8), 8'h00, {$urandom, $urandom});
        check_all_lines("after line writes");
        for (int l = 0; l < 256; l++) op(0, 11'(l * 8), 8'h00, 64'd0);
        op(3, 11'h123, 8'h5c, 64'd0); op(0, 11'h120, 8'h00, 64'd0);   // byte write -> line read
        op(1, 11'h7f8, 8'h00, 64'h0123_4567_89ab_cdef); op(2, 11'h7fb, 8'h00, 64'd0); // line write -> byte read

        // Random mixed traffic with write-back/refill pairs.
        repeat (1500) begin
            int unsigned p;
            p = $urandom_range(99);
            ad = 11'($urandom);
            if (p < 5) writeback_refill(8'($urandom), {$urandom, $urandom}, 8'($urandom));
            else begin
                kind = (p < 40) ? 0 : (p < 70) ? 1 : (p < 85) ? 2 : 3;
                op(kind, ad, 8'($urandom), {$urandom, $urandom});
            end
        end
        check_all_lines("after random traffic");

        // Resets during line accesses.
        reset_line_write(1'b0, 3, 8'h11);
        reset_line_write(1'b1, 3, 8'h22);
        reset_line_write(1'b1, 200, 8'hEE);
        reset_line_read(8'h33);
        if (n_wr != n_commit) fail($sformatf("WR commands %0d, commits %0d", n_wr, n_commit));
`ifdef DRAM_MODEL_MATCH
        check_shadow();
        $display("MODEL_MATCH clocks=%0d read_dq_samples=%0d lines=256", n_match_clk, n_match_data);
`endif

        if (!(n_pairs && n_rst_cancel && n_rst_drain >= 2 && n_rst_read && lat_n[0] && lat_n[1] && lat_n[2] && lat_n[3]))
            fail("coverage count below 1");
        $display("LATENCY clk (min..max): line_read=%0d..%0d line_write=%0d..%0d byte_read=%0d..%0d byte_write=%0d..%0d",
                 lat_min[0], lat_max[0], lat_min[1], lat_max[1], lat_min[2], lat_max[2], lat_min[3], lat_max[3]);
        $display("COVER line_reads=%0d line_writes=%0d byte_reads=%0d byte_writes=%0d pairs=%0d reset cancel/drain/read=%0d/%0d/%0d",
                 lat_n[0], lat_n[1], lat_n[2], lat_n[3], n_pairs, n_rst_cancel, n_rst_drain, n_rst_read);
        if (fails == 0)
            $display("DRAM_LINE_PASS CL=%0d CWL=%0d tRCD=%0d completions=%0d RD=%0d WR=%0d commits=%0d",
                     CL_CYCLES, CWL_CYCLES, T_RCD_CYCLES, n_done, n_rd, n_wr, n_commit);
        else
            $display("DRAM_LINE_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #50ms;
        $display("FAIL global timeout");
        $finish;
    end
endmodule
`undef TBL_MODEL_WORD

module tb_dram_line_alt;
    tb_dram_line #(.T_RCD_CYCLES(12), .CL_CYCLES(10), .CWL_CYCLES(11)) test();
endmodule
