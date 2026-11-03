`timescale 1ns/1ps
// Pair test: the data cache on the DRAM controller line port with the
// behavioral DRAM model, the RAM path of the SoC:
//   ahb_lite_master_bfm -> cache (AHB-Lite slave) -> dram_controller (line
//   port) -> dram
// Checks (reference written here):
//   - Every completed read, in program order, against a 2 KiB byte reference.
//   - Cache response rules (ahb_lite_slave_checker, SVA).
//   - Counters: cache misses = controller RD commands (one per refill),
//     cache write-backs = WR commands = model commits (no RMW).
//   - Final contents: model array merged with the valid cache lines equals the
//     reference; clean cache lines equal the model.
// Scenarios: conflict set with dirty evictions, working set, sequential
// read, random over 0x8000-0x87FF, with random idle cycles.
// Prints CACHE_DRAM_PASS only if no check failed.
module tb_cache_dram;
    reg clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;

    wire [15:0] haddr;
    wire [1:0]  htrans;
    wire        hwrite;
    wire [2:0]  hsize;
    wire [7:0]  hwdata, hrdata;
    wire        hready, hresp;
    wire        mreq, mwrite, mack;
    wire [7:0]  maddr;
    wire [63:0] mwdata, mrdata;
    wire [15:0] n_access, n_miss, n_wb;
    wire        busy, initialized;
    wire ck_t, ck_c, cke, csn, actn;
    wire [1:0] bg, ba;
    wire [17:0] a;
    tri [7:0] dq;
    tri dqs_t, dqs_c;

    ahb_lite_master_bfm bfm (
        .clk(clk), .rstn(rstn), .haddr(haddr), .htrans(htrans), .hwrite(hwrite),
        .hsize(hsize), .hwdata(hwdata), .hrdata(hrdata), .hready(hready), .hresp(hresp));

    // Point-to-point: the cache is the only slave, so HREADY is its HREADYOUT.
    cache dut_cache (
        .i_clk(clk), .i_rstn(rstn),
        .i_hsel(1'b1), .i_haddr(haddr), .i_htrans(htrans), .i_hwrite(hwrite),
        .i_hsize(hsize), .i_hwdata(hwdata), .i_hready(hready),
        .o_hreadyout(hready), .o_hresp(hresp), .o_hrdata(hrdata),
        .o_mem_req(mreq), .o_mem_write(mwrite), .o_mem_address(maddr),
        .o_mem_wdata(mwdata), .i_mem_ack(mack), .i_mem_rdata(mrdata),
        .o_access_count(n_access), .o_miss_count(n_miss), .o_writeback_count(n_wb));

    dram_controller dut_ctrl (
        .i_clk(clk), .i_rst_n(rstn), .i_req(mreq), .i_write(mwrite), .i_line(1'b1),
        .i_addr({maddr, 3'b000}), .i_wdata(8'h00), .i_line_wdata(mwdata),
        .o_ready(mack), .o_rdata(), .o_line_rdata(mrdata),
        .o_error(), .o_busy(busy), .o_initialized(initialized),
        .o_dram_ck_t(ck_t), .o_dram_ck_c(ck_c), .o_dram_cke(cke),
        .o_dram_csn(csn), .o_dram_actn(actn), .o_dram_bg(bg),
        .o_dram_ba(ba), .o_dram_a(a), .io_dram_dq(dq),
        .io_dram_dqs_t(dqs_t), .io_dram_dqs_c(dqs_c));

    dram memory_model (
        .ck_t(ck_t), .ck_c(ck_c), .cke(cke), .csn(csn), .actn(actn),
        .bg(bg), .ba(ba), .a(a), .dq(dq), .dqs_t(dqs_t), .dqs_c(dqs_c));

    ahb_lite_slave_checker #(.MAX_WAIT(600)) chk (
        .clk(clk), .rstn(rstn), .hsel(1'b1), .htrans(htrans),
        .hready(hready), .hreadyout(hready), .hresp(hresp));

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // Command and commit monitors on the model.
    wire [4:0] opcode = {csn, actn, a[16], a[15], a[14]};
    int unsigned n_rd = 0, n_wr = 0, n_commit = 0;
    always @(posedge ck_t) begin
        if (opcode == 5'b01101) n_rd++;
        if (opcode == 5'b01100) n_wr++;
        if (memory_model.data_write === 1'b1) n_commit++;
    end
    always @(posedge clk)
        if (dut_ctrl.u_core.r_dq_oe === 1'b1 && memory_model.dq_oe === 1'b1) fail("DQ contention");

    logic [7:0] ref_b [0:2047];
    int unsigned n_reads = 0, n_writes = 0, n_hit_wait0 = 0, miss_n = 0, miss_sum = 0, miss_max = 0;

    task automatic wait_idle();
        int unsigned t = 0;
        do begin @(negedge clk); t++; end while (!bfm.idle() && t < 2000000);
        if (!bfm.idle()) fail("BFM did not finish");
    endtask

    // Results in program order: reads against the reference, writes update it.
    task automatic check_results();
        for (int i = 0; i < bfm.results.size(); i++) begin
            logic [15:0] ad;
            logic [7:0] wd, rd;
            bit w, r;
            int unsigned wc;
            ad = bfm.results[i].addr; w = bfm.results[i].write; wd = bfm.results[i].wdata;
            rd = bfm.results[i].rdata; r = bfm.results[i].resp; wc = bfm.results[i].wait_cycles;
            if (r) fail($sformatf("HADDR=%h got ERROR", ad));
            if (w) begin
                ref_b[ad[10:0]] = wd; n_writes++;
            end else begin
                n_reads++;
                if (rd !== ref_b[ad[10:0]])
                    fail($sformatf("read %h = %h, expected %h", ad, rd, ref_b[ad[10:0]]));
            end
            if (wc == 0) n_hit_wait0++;
            else begin
                miss_n++; miss_sum += wc;
                if (wc > miss_max) miss_max = wc;
            end
        end
        bfm.results.delete();
    endtask

    task automatic push(input logic [10:0] a11, input bit w);
        int unsigned id;
        id = bfm.push(16'h8000 | 16'(a11), w, 8'($urandom),
                      ($urandom_range(99) < 80) ? 0 : $urandom_range(3, 1));
    endtask

    task automatic check_contents();
        for (int b = 0; b < 2048; b++) begin
            int l, idx, tg;
            logic [63:0] ln;
            l = b >> 3; idx = l % 8; tg = l >> 3;
            if (dut_cache.r_valid[idx] && dut_cache.r_tag[idx] == tg) ln = dut_cache.r_data[idx];
            else ln = memory_model.mem[l / 16][l % 16];
            if (ln[(b % 8) * 8 +: 8] !== ref_b[b])
                fail($sformatf("contents byte %03h = %h, expected %h", b, ln[(b % 8) * 8 +: 8], ref_b[b]));
        end
        for (int idx = 0; idx < 8; idx++) begin
            int l;
            l = {dut_cache.r_tag[idx], 3'(idx)};
            if (dut_cache.r_valid[idx] && !dut_cache.r_dirty[idx] &&
                dut_cache.r_data[idx] !== memory_model.mem[l / 16][l % 16])
                fail($sformatf("clean cache line %0d differs from the model", idx));
        end
    endtask

    initial begin
        for (int b = 0; b < 2048; b++) ref_b[b] = 8'((b * 37) ^ (b >> 3) ^ (b >> 8) ^ 8'h5a);
        for (int l = 0; l < 256; l++)
            for (int k = 0; k < 8; k++) memory_model.mem[l / 16][l % 16][k*8 +: 8] = ref_b[l * 8 + k];
        repeat (4) @(negedge clk);
        rstn = 1'b1;

        // 1. Conflict set: eight lines on cache index 0, reads and writes.
        repeat (600) push(11'({$urandom_range(7), 3'b000, 3'($urandom)}) , $urandom_range(99) < 50);
        wait_idle(); check_results();
        // 2. Working set: six lines on distinct indices.
        repeat (1500) push(11'h100 + 11'($urandom_range(47)), $urandom_range(99) < 40);
        wait_idle(); check_results();
        // 3. Sequential read of 512 bytes.
        for (int i = 0; i < 512; i++) push(11'h400 + 11'(i), 1'b0);
        wait_idle(); check_results();
        // 4. Random over the whole RAM.
        repeat (800) push(11'($urandom), $urandom_range(99) < 40);
        wait_idle(); check_results();

        check_contents();
        if (n_miss != 16'(n_rd)) fail($sformatf("cache misses %0d, RD commands %0d", n_miss, n_rd));
        if (n_wb != 16'(n_wr) || n_wr != n_commit)
            fail($sformatf("write-backs %0d, WR %0d, commits %0d", n_wb, n_wr, n_commit));
        if (n_access != 16'(n_reads + n_writes)) fail("access count");
        fails += chk.fails;

        $display("COVER accesses=%0d reads=%0d writes=%0d misses=%0d writebacks=%0d RD=%0d WR=%0d",
                 n_access, n_reads, n_writes, n_miss, n_wb, n_rd, n_wr);
        if (fails == 0)
            $display("CACHE_DRAM_PASS accesses=%0d hit_rate=%0d%% misses=%0d writebacks=%0d miss_wait_avg=%0d miss_wait_max=%0d",
                     n_access, (100 * (n_access - n_miss)) / n_access, n_miss, n_wb,
                     miss_sum / (miss_n ? miss_n : 1), miss_max);
        else
            $display("CACHE_DRAM_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #50ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
