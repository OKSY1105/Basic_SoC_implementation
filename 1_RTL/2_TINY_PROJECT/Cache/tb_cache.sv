`timescale 1ns/1ps
// Self-checking test for Cache/cache.v through its AHB-Lite slave port.
// - AHB master: runs an operation list, pipelined (the next address phase is
//   presented during the current data phase), holds the address phase while
//   HREADY=0, holds HWDATA through a write data phase, random idle gaps.
// - Another slave shares the bus. While its data phase holds HREADY low, the
//   cache must not take the address phase presented to it.
// - Reference: flat 2 KiB byte memory. Line memory: 256 x 64-bit, each line
//   request completes after 1..8 cycles and must not change while waiting.
// - Shadow: an independent direct-mapped write-back model predicts hits,
//   misses and write-backs. A predicted hit must complete in its first
//   data-phase cycle; the cache counters must match the shadow.
// - Contents: valid lines + memory equal the reference; clean lines equal
//   memory. Unsupported HSIZE gets a two-cycle ERROR without side effects.
// Ends with CACHE_PASS, or FAIL lines and $fatal.
module tb_cache;
    localparam integer INDEX_W = 3;
    localparam integer LINES = 1 << INDEX_W;
    localparam integer MAXOPS = 40000;
    localparam [1:0] K_BYTE = 2'd0, K_BADSIZE = 2'd1, K_OTHER = 2'd2;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rstn = 0;

    // AHB master outputs, driven at negedge.
    reg hsel = 0, hwrite = 0;
    reg [1:0] htrans = 2'b00;
    reg [15:0] haddr = 0;
    reg [2:0] hsize = 0;
    reg [7:0] hwdata = 0;
    // Another slave on the same bus, driven at negedge.
    reg other_dp = 0, other_rdy = 1;
    integer other_left = 0;
    wire hreadyout, hresp;
    wire [7:0] hrdata;
    wire hready = other_dp ? other_rdy : hreadyout;
    // Memory side.
    wire mreq, mwrite;
    wire [7:0] maddr;
    wire [63:0] mwdata;
    reg mack = 0;
    reg [63:0] mrdata = 0;
    wire [15:0] n_access, n_miss, n_wb;

    cache #(.INDEX_W(INDEX_W)) dut (
        .i_clk(clk), .i_rstn(rstn),
        .i_hsel(hsel), .i_haddr(haddr), .i_htrans(htrans), .i_hwrite(hwrite),
        .i_hsize(hsize), .i_hwdata(hwdata), .i_hready(hready),
        .o_hreadyout(hreadyout), .o_hresp(hresp), .o_hrdata(hrdata),
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

    // ---------------- operation list ----------------
    reg [1:0] op_kind [0:MAXOPS-1];
    reg op_w [0:MAXOPS-1];
    reg [15:0] op_a [0:MAXOPS-1];
    reg [7:0] op_d [0:MAXOPS-1];
    integer op_gap [0:MAXOPS-1];                 // idle cycles before the address phase
    integer op_wait [0:MAXOPS-1];                // other-slave wait cycles
    integer nops = 0;
    task add_op(input [1:0] kind, input w, input [15:0] a, input [7:0] d,
                input integer gap, input integer wt);
        begin
            op_kind[nops] = kind; op_w[nops] = w; op_a[nops] = a; op_d[nops] = d;
            op_gap[nops] = gap; op_wait[nops] = wt; nops = nops + 1;
        end
    endtask

    // ---------------- shadow model ----------------
    reg [LINES-1:0] s_valid = 0, s_dirty = 0;
    integer s_tag [0:LINES-1];
    integer exp_access = 0, exp_miss = 0, exp_wb = 0, hits = 0;
    integer miss_cycles = 0, max_miss_cycles = 0, bad_size = 0, other_ops = 0;
    integer bus_cycles = 0;

    reg dp_valid = 0, dp_pred_hit = 0, ap_hold = 0;
    reg other_begin = 0, other_end = 0;
    integer dp_op = 0, dp_cycles = 0, gap_left = 0, other_begin_wait = 0;

    task predict(input integer i);
        integer a, idx, tg;
        begin
            a = op_a[i] & 16'h07ff;
            idx = (a >> 3) % LINES; tg = a >> (3 + INDEX_W);
            dp_pred_hit = s_valid[idx] && (s_tag[idx] == tg);
            if (!dp_pred_hit) begin
                exp_miss = exp_miss + 1;
                if (s_valid[idx] && s_dirty[idx]) exp_wb = exp_wb + 1;
                s_valid[idx] = 1; s_tag[idx] = tg; s_dirty[idx] = 0;
            end
            if (op_w[i]) s_dirty[idx] = 1;
        end
    endtask

    task complete(input integer i, input r, input [7:0] rd);
        integer a;
        begin
            a = op_a[i] & 16'h07ff;
            case (op_kind[i])
                K_BYTE: begin
                    if (r !== 1'b0) begin
                        $display("FAIL unexpected ERROR at %04h", op_a[i]); errors = errors + 1;
                    end
                    if (!op_w[i] && rd !== ref_mem[a]) begin
                        $display("FAIL read %04h got=%02h expected=%02h", op_a[i], rd, ref_mem[a]);
                        errors = errors + 1;
                    end
                    if (op_w[i]) ref_mem[a] = op_d[i];
                    exp_access = exp_access + 1;
                    if (dp_pred_hit) begin
                        hits = hits + 1;
                        if (dp_cycles != 0) begin
                            $display("FAIL hit at %04h waited %0d cycles", op_a[i], dp_cycles);
                            errors = errors + 1;
                        end
                    end else begin
                        miss_cycles = miss_cycles + dp_cycles;
                        if (dp_cycles > max_miss_cycles) max_miss_cycles = dp_cycles;
                    end
                end
                K_BADSIZE: begin
                    if (r !== 1'b1 || dp_cycles != 1) begin
                        $display("FAIL HSIZE!=byte at %04h needs a two-cycle ERROR (resp=%b cycles=%0d)",
                                 op_a[i], r, dp_cycles + 1);
                        errors = errors + 1;
                    end
                    bad_size = bad_size + 1;
                end
                default: ;
            endcase
        end
    endtask

    // Runs operations first..last as a pipelined AHB-Lite master.
    task run_ops(input integer first, input integer last);
        integer next;
        reg h, r;
        reg [7:0] rd;
        begin
            next = first; ap_hold = 0;
            gap_left = (first <= last) ? op_gap[first] : 0;
            while (next <= last || dp_valid) begin
                @(negedge clk);
                if (other_end) begin other_dp = 0; other_end = 0; end
                if (other_begin) begin
                    other_dp = 1; other_left = other_begin_wait; other_begin = 0;
                end else if (other_dp && other_left > 0) other_left = other_left - 1;
                other_rdy = (other_left == 0);
                if (!ap_hold) begin
                    if (next <= last && gap_left == 0) begin
                        htrans = 2'b10; haddr = op_a[next]; hwrite = op_w[next];
                        hsize = (op_kind[next] == K_BADSIZE) ? 3'b001 : 3'b000;
                        hsel = (op_kind[next] != K_OTHER);
                    end else begin
                        htrans = 2'b00; hsel = 0; hwrite = 0; hsize = 0;
                        if (next <= last) gap_left = gap_left - 1;
                    end
                end
                if (dp_valid && op_kind[dp_op] == K_BYTE && op_w[dp_op]) hwdata = op_d[dp_op];
                else hwdata = $random(seed);

                @(posedge clk);
                h = hready; r = hresp; rd = hrdata;
                bus_cycles = bus_cycles + 1;
                if (other_dp && (dut.r_dp || dut.r_err)) begin
                    $display("FAIL cache holds a data phase during another slave's transfer");
                    errors = errors + 1;
                end
                if (dp_valid) begin
                    if (op_kind[dp_op] == K_BADSIZE && !h && dp_cycles == 0 && r !== 1'b1) begin
                        $display("FAIL first ERROR cycle missing at %04h", op_a[dp_op]);
                        errors = errors + 1;
                    end
                    if (h) begin
                        complete(dp_op, r, rd);
                        if (op_kind[dp_op] == K_OTHER) other_end = 1;
                        dp_valid = 0;
                    end else begin
                        dp_cycles = dp_cycles + 1;
                        if (dp_cycles > 400) begin
                            $display("FAIL data phase never completed at %04h", op_a[dp_op]);
                            errors = errors + 1; dp_valid = 0;
                        end
                    end
                end
                if (htrans == 2'b10 && h) begin
                    dp_valid = 1; dp_op = next; dp_cycles = 0;
                    if (op_kind[next] == K_BYTE) predict(next);
                    if (op_kind[next] == K_OTHER) begin
                        other_begin = 1; other_begin_wait = op_wait[next];
                        other_ops = other_ops + 1;
                    end
                    next = next + 1;
                    gap_left = (next <= last) ? op_gap[next] : 0;
                    ap_hold = 0;
                end else ap_hold = (htrans == 2'b10);
            end
            @(negedge clk);
            htrans = 2'b00; hsel = 0;
            if (other_end) begin other_dp = 0; other_end = 0; end
            other_rdy = 1;
        end
    endtask

    task check_contents(input [127:0] label);
        integer b, idx, tg;
        reg [63:0] line;
        reg [7:0] v;
        begin
            @(negedge clk);
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
            @(negedge clk);
            if (n_access !== exp_access || n_miss !== exp_miss || n_wb !== exp_wb ||
                m_reads != exp_miss || m_writes != exp_wb) begin
                $display("FAIL %0s counters access=%0d/%0d miss=%0d/%0d wb=%0d/%0d mem_rd=%0d mem_wr=%0d",
                         label, n_access, exp_access, n_miss, exp_miss, n_wb, exp_wb, m_reads, m_writes);
                errors = errors + 1;
            end
        end
    endtask

    integer p_access = 0, p_miss = 0, p_wb = 0, p_cycles = 0;
    task phase_start;
        begin p_access = exp_access; p_miss = exp_miss; p_wb = exp_wb; p_cycles = bus_cycles; end
    endtask
    task phase_report(input [127:0] name);
        integer n, m;
        begin
            n = exp_access - p_access; m = exp_miss - p_miss;
            $display("PHASE %0s accesses=%0d misses=%0d writebacks=%0d hit_rate=%0d%% bus_cycles=%0d",
                     name, n, m, exp_wb - p_wb, (100 * (n - m)) / n, bus_cycles - p_cycles);
        end
    endtask

    task restart_expectations;
        begin
            s_valid = 0; s_dirty = 0;
            exp_access = 0; exp_miss = 0; exp_wb = 0;
            m_reads = 0; m_writes = 0;
        end
    endtask

    // Hot set: three lines share index 0 (tags differ) to force dirty evictions.
    reg [10:0] hot [0:7];

    task add_random(input integer count, input integer gaps);
        integer i, kind, w, gap;
        reg [15:0] a;
        begin
            for (i = 0; i < count; i = i + 1) begin
                kind = {$random(seed)} % 100;
                gap = (gaps && ({$random(seed)} % 4) == 0) ? {$random(seed)} % 3 : 0;
                a = 16'h8000 | (({$random(seed)} % 2) ? hot[{$random(seed)} % 8]
                                                       : ({$random(seed)} % 2048));
                w = ({$random(seed)} % 10) < 4;
                if (kind < 2) add_op(K_OTHER, w, 16'hf000, 0, gap, {$random(seed)} % 5);
                else if (kind < 3) add_op(K_BADSIZE, w, a, 0, gap, 0);
                else add_op(K_BYTE, w, a, $random(seed), gap, 0);
            end
        end
    endtask

    integer i, first, total_access = 0, total_miss = 0, total_wb = 0, total_hits = 0;
    integer total_miss_cycles = 0, b2b_cycles = 0;
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

        // Directed: clean miss, pipelined hit, write hit, dirty eviction.
        first = nops;
        add_op(K_BYTE, 0, 16'h8010, 0, 0, 0);
        add_op(K_BYTE, 0, 16'h8011, 0, 0, 0);
        add_op(K_BYTE, 1, 16'h8012, 8'hab, 0, 0);
        add_op(K_BYTE, 0, 16'h8012, 0, 0, 0);
        add_op(K_BYTE, 0, 16'h8050, 0, 0, 0);
        run_ops(first, nops - 1);
        if (lines[2][23:16] !== 8'hab) begin
            $display("FAIL dirty line was not written back"); errors = errors + 1;
        end
        // Eight hits back to back: one per clock after the first address phase.
        first = nops;
        for (i = 0; i < 8; i = i + 1) add_op(K_BYTE, 0, 16'h8050 + i, 0, 0, 0);
        b2b_cycles = bus_cycles;
        run_ops(first, nops - 1);
        b2b_cycles = bus_cycles - b2b_cycles;
        if (b2b_cycles != 9) begin
            $display("FAIL 8 back-to-back hits took %0d cycles (expected 9)", b2b_cycles);
            errors = errors + 1;
        end
        // Unsupported size, then a transfer held behind another slave's wait.
        first = nops;
        add_op(K_BADSIZE, 1, 16'h8051, 8'hee, 0, 0);
        add_op(K_OTHER, 0, 16'hf000, 0, 0, 3);
        add_op(K_BYTE, 1, 16'h8051, 8'h3c, 0, 0);
        add_op(K_BYTE, 0, 16'h8051, 0, 2, 0);
        run_ops(first, nops - 1);
        check_counters("directed");
        check_contents("directed");

        // Stress: hot set + anywhere, writes, gaps, other-slave waits, bad sizes.
        phase_start; first = nops; add_random(20000, 1); run_ops(first, nops - 1);
        phase_report("stress");
        // Working set: 48 bytes (6 lines, distinct indices).
        phase_start; first = nops;
        for (i = 0; i < 5000; i = i + 1) begin
            k = 16'h8100 + ({$random(seed)} % 48);
            if (({$random(seed)} % 10) < 4) add_op(K_BYTE, 1, k, $random(seed), 0, 0);
            else add_op(K_BYTE, 0, k, 0, 0, 0);
        end
        run_ops(first, nops - 1);
        phase_report("working_set");
        // Sequential: read a 512-byte buffer back to back.
        phase_start; first = nops;
        for (i = 0; i < 512; i = i + 1) add_op(K_BYTE, 0, 16'h8400 + i, 0, 0, 0);
        run_ops(first, nops - 1);
        phase_report("sequential");
        check_counters("random");
        check_contents("random");
        total_access = exp_access; total_miss = exp_miss; total_wb = exp_wb;
        total_hits = hits; total_miss_cycles = miss_cycles;

        // Reset while a write-back waits: dirty data is lost by design, so the
        // reference becomes the memory contents.
        first = nops; add_op(K_BYTE, 1, 16'h8000 | hot[0], 8'h5a, 0, 0); run_ops(first, nops - 1);
        @(negedge clk); htrans = 2'b10; hsel = 1; haddr = 16'h8000 | hot[1]; hwrite = 0; hsize = 0;
        @(posedge clk);
        @(negedge clk); htrans = 2'b00; hsel = 0;
        wait (mreq === 1'b1);
        @(negedge clk);
        rstn = 0;
        repeat (2) @(negedge clk);
        if (mreq !== 1'b0 || hreadyout !== 1'b1 || n_access !== 0) begin
            $display("FAIL reset did not clear the cache"); errors = errors + 1;
        end
        rstn = 1;
        dp_valid = 0; ap_hold = 0;
        for (k = 0; k < 2048; k = k + 1) ref_mem[k] = lines[k >> 3][8 * (k % 8) +: 8];
        restart_expectations;
        first = nops; add_random(2000, 1); run_ops(first, nops - 1);
        check_counters("after reset");
        check_contents("after reset");

        if (errors != 0) begin
            $display("FAIL cache test errors=%0d", errors);
            $fatal(1);
        end else begin
            $display("CACHE_PASS accesses=%0d hits=%0d misses=%0d writebacks=%0d hit_rate=%0d%% avg_miss_cycles=%0d max_miss_cycles=%0d b2b_8hits_cycles=%0d bad_size_errors=%0d other_slave_ops=%0d",
                     total_access, total_hits, total_miss, total_wb,
                     (100 * (total_access - total_miss)) / total_access,
                     total_miss_cycles / (total_miss > 0 ? total_miss : 1), max_miss_cycles,
                     b2b_cycles, bad_size, other_ops);
        end
        $finish;
    end

    initial begin
        #50_000_000;
        $display("FAIL cache test watchdog"); $fatal(1);
    end
endmodule
