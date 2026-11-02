`timescale 1ns/1ps
// Self-checking test for Cache/cache.v.
// - Reference: flat 2 KiB byte memory, updated at every completed CPU write.
//   Every read must return the reference byte.
// - Line memory: 256 x 64-bit; each line request completes after 1..8 cycles.
//   The request must stay unchanged until ack.
// - Shadow: an independent direct-mapped write-back model predicts hits,
//   misses and write-backs. A predicted hit must be acknowledged in the
//   request cycle, and the cache counters must match the shadow.
// - Contents: valid lines + memory must equal the reference; clean lines
//   must equal memory.
// Ends with CACHE_PASS or a FAIL line followed by $fatal.
module tb_cache;
    localparam integer INDEX_W = 3;
    localparam integer LINES = 1 << INDEX_W;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rstn = 0;
    reg req = 0, wr = 0;
    reg [10:0] addr = 0;
    reg [7:0] wdata = 0;
    wire ack;
    wire [7:0] rdata;
    wire mreq, mwrite;
    wire [7:0] maddr;
    wire [63:0] mwdata;
    reg mack = 0;
    reg [63:0] mrdata = 0;
    wire [15:0] n_access, n_miss, n_wb;

    cache #(.INDEX_W(INDEX_W)) dut (
        .i_clk(clk), .i_rstn(rstn),
        .i_cpu_req(req), .i_cpu_write(wr), .i_cpu_memaddr(addr), .i_cpu_wdata(wdata),
        .o_cpu_ack(ack), .o_cpu_rdata(rdata),
        .o_mem_req(mreq), .o_mem_write(mwrite), .o_mem_address(maddr),
        .o_mem_wdata(mwdata), .i_mem_ack(mack), .i_mem_rdata(mrdata),
        .o_access_count(n_access), .o_miss_count(n_miss), .o_writeback_count(n_wb)
    );

    reg [7:0] ref_mem [0:2047];
    reg [63:0] lines [0:255];
    integer seed = 20261103, errors = 0, k;

    // ---------------- line memory model ----------------
    reg m_busy = 0;
    integer m_wait = 0, m_reads = 0, m_writes = 0;
    reg [7:0] m_addr = 0;
    reg m_write = 0;
    reg [63:0] m_wdata = 0;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            m_busy <= 0; mack <= 0;
        end else if (mack) begin
            // Completion edge: the cache samples ack now.
            if (!mreq) begin
                $display("FAIL memory request dropped before ack"); errors = errors + 1;
            end
            if (m_write) begin lines[m_addr] <= m_wdata; m_writes = m_writes + 1; end
            else m_reads = m_reads + 1;
            mack <= 0; m_busy <= 0;
        end else if (m_busy) begin
            if (!mreq || maddr !== m_addr || mwrite !== m_write ||
                (m_write && mwdata !== m_wdata)) begin
                $display("FAIL memory request changed while waiting"); errors = errors + 1;
            end
            if (m_wait <= 1) begin
                mack <= 1;
                if (!m_write) mrdata <= lines[m_addr];
            end else m_wait <= m_wait - 1;
        end else if (mreq) begin
            m_busy <= 1; m_addr <= maddr; m_write <= mwrite; m_wdata <= mwdata;
            m_wait <= 1 + ({$random(seed)} % 8);
        end
    end

    // ---------------- shadow model and CPU-side driver ----------------
    reg [LINES-1:0] s_valid = 0, s_dirty = 0;
    integer s_tag [0:LINES-1];
    integer exp_access = 0, exp_miss = 0, exp_wb = 0;
    integer hits = 0, miss_cycles = 0, max_miss_cycles = 0;

    task automatic access(input w, input [10:0] a, input [7:0] d);
        integer idx, tg, cyc;
        reg predicted_hit;
        begin
            idx = (a >> 3) % LINES;
            tg = a >> (3 + INDEX_W);
            predicted_hit = s_valid[idx] && (s_tag[idx] == tg);
            if (!predicted_hit) begin
                exp_miss = exp_miss + 1;
                if (s_valid[idx] && s_dirty[idx]) exp_wb = exp_wb + 1;
                s_valid[idx] = 1; s_tag[idx] = tg; s_dirty[idx] = 0;
            end
            if (w) s_dirty[idx] = 1;
            @(negedge clk);
            req = 1; wr = w; addr = a; wdata = d; cyc = 0;
            @(posedge clk);
            while (!ack && cyc < 200) begin cyc = cyc + 1; @(posedge clk); end
            if (!ack) begin
                $display("FAIL no ack for addr=%03h", a); errors = errors + 1;
            end else begin
                if (!w && rdata !== ref_mem[a]) begin
                    $display("FAIL read addr=%03h got=%02h expected=%02h", a, rdata, ref_mem[a]);
                    errors = errors + 1;
                end
                if (w) ref_mem[a] = d;
                exp_access = exp_access + 1;
                if (predicted_hit) begin
                    hits = hits + 1;
                    if (cyc != 0) begin
                        $display("FAIL hit at %03h took %0d extra cycles", a, cyc);
                        errors = errors + 1;
                    end
                end else begin
                    miss_cycles = miss_cycles + cyc;
                    if (cyc > max_miss_cycles) max_miss_cycles = cyc;
                end
            end
            // Withdraw the request after its completion edge; the next access
            // can still be presented in the very next cycle.
            #1 req = 0;
        end
    endtask

    task idle(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin @(negedge clk); req = 0; end
        end
    endtask

    task check_contents(input [127:0] label);
        integer b, idx, tg;
        reg [63:0] line;
        reg [7:0] v;
        begin
            @(negedge clk);   // after the last completion edge has updated the cache
            for (b = 0; b < 2048; b = b + 1) begin
                idx = (b >> 3) % LINES;
                tg = b >> (3 + INDEX_W);
                if (dut.r_valid[idx] && dut.r_tag[idx] == tg) line = dut.r_data[idx];
                else line = lines[b >> 3];
                v = line[8 * (b % 8) +: 8];
                if (v !== ref_mem[b]) begin
                    $display("FAIL %0s contents byte %03h got=%02h expected=%02h", label, b, v, ref_mem[b]);
                    errors = errors + 1;
                end
            end
            for (idx = 0; idx < LINES; idx = idx + 1)
                if (dut.r_valid[idx] && !dut.r_dirty[idx] &&
                    dut.r_data[idx] !== lines[{dut.r_tag[idx], idx[INDEX_W-1:0]}]) begin
                    $display("FAIL %0s clean line %0d differs from memory", label, idx);
                    errors = errors + 1;
                end
        end
    endtask

    task check_counters(input [127:0] label);
        begin
            @(negedge clk);   // counters update on the completion edge
            if (n_access !== exp_access || n_miss !== exp_miss || n_wb !== exp_wb ||
                m_reads != exp_miss || m_writes != exp_wb) begin
                $display("FAIL %0s counters access=%0d/%0d miss=%0d/%0d wb=%0d/%0d mem_rd=%0d mem_wr=%0d",
                         label, n_access, exp_access, n_miss, exp_miss, n_wb, exp_wb, m_reads, m_writes);
                errors = errors + 1;
            end
        end
    endtask

    task restart_expectations;
        begin
            s_valid = 0; s_dirty = 0;
            exp_access = 0; exp_miss = 0; exp_wb = 0;
            m_reads = 0; m_writes = 0;
        end
    endtask

    integer p_access = 0, p_miss = 0, p_wb = 0;
    task phase_start;
        begin p_access = exp_access; p_miss = exp_miss; p_wb = exp_wb; end
    endtask
    task phase_report(input [127:0] name);
        integer n, m;
        begin
            n = exp_access - p_access; m = exp_miss - p_miss;
            $display("PHASE %0s accesses=%0d misses=%0d writebacks=%0d hit_rate=%0d%%",
                     name, n, m, exp_wb - p_wb, (100 * (n - m)) / n);
        end
    endtask

    // Hot set: three lines share index 0 (tags differ) to force dirty evictions.
    reg [10:0] hot [0:7];
    integer i, total_access = 0, total_miss = 0, total_wb = 0, total_hits = 0, total_miss_cycles = 0;
    reg [10:0] a;
    initial begin
        hot[0] = 11'h000; hot[1] = 11'h040; hot[2] = 11'h080; hot[3] = 11'h10b;
        hot[4] = 11'h3f8; hot[5] = 11'h7ff; hot[6] = 11'h21c; hot[7] = 11'h455;
        for (k = 0; k < 2048; k = k + 1) ref_mem[k] = $random(seed);
        for (k = 0; k < 256; k = k + 1)
            lines[k] = {ref_mem[8*k+7], ref_mem[8*k+6], ref_mem[8*k+5], ref_mem[8*k+4],
                        ref_mem[8*k+3], ref_mem[8*k+2], ref_mem[8*k+1], ref_mem[8*k]};
        restart_expectations;
        repeat (3) @(negedge clk);
        rstn = 1;

        // Directed: clean miss, hit in the request cycle, write hit, dirty eviction.
        access(0, 11'h010, 0);          // miss, refill line 2
        access(0, 11'h011, 0);          // hit
        access(1, 11'h012, 8'hab);      // write hit -> dirty
        access(0, 11'h012, 0);          // read back ab
        access(0, 11'h050, 0);          // same index, other tag: write back + refill
        if (lines[2][23:16] !== 8'hab) begin
            $display("FAIL dirty line was not written back"); errors = errors + 1;
        end
        for (i = 0; i < 8; i = i + 1) access(0, 11'h050 + i, 0);   // 8 hits back to back
        check_counters("directed");
        check_contents("directed");

        // Stress: half from a conflict-heavy hot set, half anywhere; 40% writes.
        phase_start;
        for (i = 0; i < 20000; i = i + 1) begin
            a = ({$random(seed)} % 2) ? hot[{$random(seed)} % 8] : ({$random(seed)} % 2048);
            if (({$random(seed)} % 10) < 4) access(1, a, $random(seed));
            else access(0, a, 0);
            if (({$random(seed)} % 4) == 0) idle({$random(seed)} % 3);
        end
        phase_report("stress");
        // Working set: 48 bytes (6 lines, distinct indices), as program variables.
        phase_start;
        for (i = 0; i < 5000; i = i + 1) begin
            a = 11'h100 + ({$random(seed)} % 48);
            if (({$random(seed)} % 10) < 4) access(1, a, $random(seed));
            else access(0, a, 0);
        end
        phase_report("working_set");
        // Sequential: read a 512-byte buffer once, as an array walk.
        phase_start;
        for (i = 0; i < 512; i = i + 1) access(0, 11'h400 + i, 0);
        phase_report("sequential");
        check_counters("random");
        check_contents("random");
        total_access = exp_access; total_miss = exp_miss; total_wb = exp_wb; total_hits = hits;
        total_miss_cycles = miss_cycles;

        // Reset while a line request waits: dirty lines are lost by design, so
        // the reference becomes the memory contents.
        access(1, hot[0], 8'h5a);
        idle(1);
        @(negedge clk); req = 1; wr = 0; addr = hot[1];   // conflicts with hot[0]: write-back starts
        wait (mreq === 1'b1);
        @(negedge clk);
        rstn = 0; req = 0;
        repeat (2) @(negedge clk);
        if (mreq !== 1'b0 || ack !== 1'b0 || n_access !== 0) begin
            $display("FAIL reset did not clear the cache"); errors = errors + 1;
        end
        rstn = 1;
        for (k = 0; k < 2048; k = k + 1) ref_mem[k] = lines[k >> 3][8 * (k % 8) +: 8];
        restart_expectations;
        for (i = 0; i < 2000; i = i + 1) begin
            a = ({$random(seed)} % 2) ? hot[{$random(seed)} % 8] : ({$random(seed)} % 2048);
            if (({$random(seed)} % 10) < 4) access(1, a, $random(seed));
            else access(0, a, 0);
        end
        check_counters("after reset");
        check_contents("after reset");

        if (errors != 0) begin
            $display("FAIL cache test errors=%0d", errors);
            $fatal(1);
        end else begin
            $display("CACHE_PASS accesses=%0d hits=%0d misses=%0d writebacks=%0d hit_rate=%0d%% avg_miss_cycles=%0d max_miss_cycles=%0d",
                     total_access, total_hits, total_miss, total_wb,
                     (100 * (total_access - total_miss)) / total_access,
                     total_miss_cycles / (total_miss > 0 ? total_miss : 1), max_miss_cycles);
        end
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL cache test watchdog"); $fatal(1);
    end
endmodule
