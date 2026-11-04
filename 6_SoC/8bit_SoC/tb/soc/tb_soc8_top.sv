`timescale 1ns/1ps
// Integration TB for soc8_top (step 2 of integration, 05_integration I01/I02).
// DUT: soc8_top + sim/models/soc8_dram_model.v (behavioral dram.v), or with
// -d SOC8_BRAM_DRAM the board model DRAM/dram_bram_model.v wired as on the
// board (scripts/run_soc8_top_tb.sh: SOC8_DRAM_MODEL=bram).
// Programs: tb/soc/programs/*.asm, assembled to <PROG_DIR>/<name>.mem
// (+PROG_DIR=...). Each test holds reset, loads its image into the ROM array
// (TB back door, also kept as the TB's own copy) and releases reset.
//
// Tests (FULL=1: all; FULL=0: ram_basic and uart_echo_irq with 8 bytes,
// nominal and 1.5% fast sender)
//   ram_basic        256-byte RAM write/read through cache and DRAM, ROM data
//                    reads (little endian), UART TX of the results, HALT
//   uart_echo_irq    interrupt-driven echo, delayed by one byte; one handler
//                    entry per received byte (RX pop is the last access
//                    before RETI: zero-margin IRQ fall, H059 6-1). Bytes are
//                    sent back to back (first half) and with gaps, by a
//                    sender whose clock is nominal, 1.5% fast or 1.5% slow
//   fault_unmapped   LD from 0x4000: default slave ERROR, fault code 3
//   fault_rom_write  ST to the ROM region: ROM ERROR, fault code 3
//   reset_mid_run    ram_basic with 20 random resets (also shorter than a
//                    clock) during misses and DRAM bursts, then a full run
// Checks (references written here, independent of the DUT):
//   - Data-port scoreboard on the bus: every completed RAM read equals the
//     last write to that byte (bytes not written since reset are learned),
//     every ROM read equals the image byte, ERROR completions counted.
//   - UART: 8E1 receiver on TXD (parity, stop) and 8E1 driver on RXD; frames
//     cut by a reset are discarded.
//   - Cache <-> DRAM controller: every ack is for the request the controller
//     latched; no ack during reset or when the cache waits for none.
//   - DRAM pins: RD commands = cache misses, WR commands = model commits =
//     cache write-backs (tests without a mid-run reset).
//   - Final RAM contents: valid cache lines + model array = reference.
//   - SVA: AHB-Lite bus and RAM slave responses, APB3 master rules, CPU
//     AHB master rules and interrupt rules (-d AHB_LITE_SVA -d APB_SVA
//     -d CPU8_SVA). Checker failures print lines starting with FAIL.
// Prints SOC8_TOP_PASS only if no check failed; the run also needs no FAIL
// line from the checkers.
module tb_soc8_top;
    parameter integer BAUD = 3_125_000;           // 32 clocks per bit at 100 MHz
    parameter integer FULL = 1;
    localparam real BIT_NS = 1.0e9 / BAUD;

    reg clk = 1'b0, rst_n_raw = 1'b0, rxd = 1'b1;
    always #5 clk = ~clk;

    wire        txd, ck_t, ck_c, cke, csn, actn, dq_oe, dqs_t, dqs_c, dqs_oe;
    wire [1:0]  bg, ba;
    wire [17:0] a;
    wire [7:0]  dq_o, dq_i;
    wire        rst_sync, halted, fault, irq, irq_active, dram_init;
    wire [2:0]  fault_code;
    wire [15:0] pc, n_acc, n_miss, n_wb, err_addr, err_cnt;

    soc8_top #(.BAUD_RATE(BAUD)) dut (
        .i_clk(clk), .i_rst_n(rst_n_raw), .i_uart_rxd(rxd), .o_uart_txd(txd),
        .o_dram_ck_t(ck_t), .o_dram_ck_c(ck_c), .o_dram_cke(cke), .o_dram_csn(csn),
        .o_dram_actn(actn), .o_dram_bg(bg), .o_dram_ba(ba), .o_dram_a(a),
        .o_dram_dq(dq_o), .o_dram_dq_oe(dq_oe), .i_dram_dq(dq_i),
        .o_dram_dqs_t(dqs_t), .o_dram_dqs_c(dqs_c), .o_dram_dqs_oe(dqs_oe),
        .o_rst_n(rst_sync), .o_halted(halted), .o_fault(fault), .o_fault_code(fault_code),
        .o_pc(pc), .o_irq(irq), .o_irq_active(irq_active), .o_dram_initialized(dram_init),
        .o_cache_access_count(n_acc), .o_cache_miss_count(n_miss),
        .o_cache_writeback_count(n_wb), .o_bus_err_addr(err_addr), .o_bus_err_count(err_cnt));

`ifdef SOC8_BRAM_DRAM
    // Board memory: the BRAM-based model on the core's split pins, wired as
    // on the board (no tri-state; the model's DQ output is the core's input).
    wire bram_dq_oe;
    dram_bram_model mem_bram (
        .i_clk(clk), .i_ck_t(ck_t), .i_ck_c(ck_c), .i_cke(cke), .i_csn(csn),
        .i_actn(actn), .i_bg(bg), .i_ba(ba), .i_a(a), .i_dq(dq_o),
        .o_dq(dq_i), .o_dq_oe(bram_dq_oe), .i_dqs_t(dqs_t), .i_dqs_c(dqs_c));
    `define SOC8_MODEL mem_bram
    `define SOC8_MODEL_LINE(l) mem_bram.mem[l]
`else
    soc8_dram_model mem (
        .i_ck_t(ck_t), .i_ck_c(ck_c), .i_cke(cke), .i_csn(csn), .i_actn(actn),
        .i_bg(bg), .i_ba(ba), .i_a(a), .i_dq(dq_o), .i_dq_oe(dq_oe), .o_dq(dq_i),
        .i_dqs_t(dqs_t), .i_dqs_c(dqs_c), .i_dqs_oe(dqs_oe));
    `define SOC8_MODEL mem.u_dram
    `define SOC8_MODEL_LINE(l) mem.u_dram.mem[(l) / 16][(l) % 16]
`endif

    // ---------------------------------------------------------------- checkers
    ahb_lite_slave_checker #(.MAX_WAIT(600)) chk_bus (
        .clk(clk), .rstn(rst_sync), .hsel(1'b1), .htrans(dut.w_d_htrans),
        .hready(dut.w_d_hready), .hreadyout(dut.w_d_hready), .hresp(dut.w_d_hresp));
    ahb_lite_slave_checker #(.MAX_WAIT(600)) chk_ram (
        .clk(clk), .rstn(rst_sync), .hsel(dut.w_hsel_ram), .htrans(dut.w_d_htrans),
        .hready(dut.w_d_hready), .hreadyout(dut.w_ram_hreadyout), .hresp(dut.w_ram_hresp));
    apb_checker chk_apb (
        .clk(clk), .rstn(rst_sync), .psel(dut.w_psel), .penable(dut.w_penable),
        .paddr(dut.w_paddr), .pwrite(dut.w_pwrite), .pwdata(dut.w_pwdata), .pready(dut.w_pready));
    cpu8_ahb_checker chk_cpu (
        .clk(clk), .rst_n(rst_sync),
        .i_htrans(dut.w_i_htrans), .i_haddr(dut.w_i_haddr), .i_hsize(dut.w_i_hsize),
        .i_hburst(dut.u_cpu.o_i_hburst), .i_hprot(dut.u_cpu.o_i_hprot), .i_hwrite(dut.w_i_hwrite),
        .i_hready(dut.w_i_hready), .i_hresp(dut.w_i_hresp),
        .d_htrans(dut.w_d_htrans), .d_haddr(dut.w_d_haddr), .d_hsize(dut.w_d_hsize),
        .d_hburst(dut.u_cpu.o_d_hburst), .d_hprot(dut.u_cpu.o_d_hprot), .d_hwrite(dut.w_d_hwrite),
        .d_hwdata(dut.w_d_hwdata), .d_hready(dut.w_d_hready), .d_hresp(dut.w_d_hresp),
        .halted(halted), .i_hold(dut.u_cpu.r_i_hold), .redirect(dut.u_cpu.w_redirect),
        .d_issue_mem(dut.u_cpu.w_id_issue && dut.u_cpu.w_memory && !dut.u_cpu.w_id_fault),
        .fetch_overflow(dut.u_cpu.r_id_valid && !dut.u_cpu.w_id_issue &&
                        dut.u_cpu.r_sk_valid && dut.u_cpu.w_if_land));
    cpu8_irq_checker chk_irq (
        .clk(clk), .rst_n(rst_sync), .irq(irq), .ie(dut.u_cpu.r_ie), .bank(dut.u_cpu.r_bank),
        .int_take(dut.u_cpu.w_int_take), .id_issue(dut.u_cpu.w_id_issue),
        .reti_issue(dut.u_cpu.w_reti_issue), .id_valid(dut.u_cpu.r_id_valid),
        .m_valid(dut.u_cpu.r_m_valid), .m_done(dut.u_cpu.w_m_done), .d_htrans(dut.w_d_htrans));

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 30) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // ------------------------------------------------------- reset bookkeeping
    int unsigned resets_seen = 0;
    always @(negedge rst_sync) resets_seen++;

    // ---------------------------------------------------- UART receiver (TXD)
    logic [7:0] tx_q [$];
    initial forever begin : tx_monitor
        int unsigned r0;
        logic [7:0] b;
        logic p, s;
        @(negedge txd);
        r0 = resets_seen;
        #(BIT_NS * 1.5);
        for (int i = 0; i < 8; i++) begin b[i] = txd; #(BIT_NS); end
        p = txd;
        #(BIT_NS);
        s = txd;
        if (r0 == resets_seen && rst_sync === 1'b1) begin
            if (p !== ^b || s !== 1'b1)
                fail($sformatf("UART TX frame %02h parity=%b stop=%b", b, p, s));
            tx_q.push_back(b);
        end
    end

    // ------------------------------------------------------ UART driver (RXD)
    // One 8E1 frame with no idle bit after it; bit_ns models the sender clock
    // (BIT_NS is the nominal baud, BIT_NS / 1.015 a sender 1.5% fast).
    task automatic send_byte(input logic [7:0] b, input real bit_ns, input bit bad_par = 1'b0);
        rxd = 1'b0;
        #(bit_ns);
        for (int i = 0; i < 8; i++) begin rxd = b[i]; #(bit_ns); end
        rxd = (^b) ^ bad_par;
        #(bit_ns);
        rxd = 1'b1;
        #(bit_ns);
    endtask

    // ------------------------------------------------- data-port scoreboard
    logic [7:0]  ram_ref [0:2047];
    bit          ram_known [0:2047];
    logic [15:0] rom_ref [0:4095];
    int unsigned n_ram_rd = 0, n_ram_wr = 0, n_rom_rd = 0, n_uart_acc = 0, n_err = 0;
    reg          sb_dp = 1'b0, sb_w = 1'b0;
    reg [15:0]   sb_a = 16'd0;
    always @(negedge rst_sync) for (int i = 0; i < 2048; i++) ram_known[i] = 1'b0;
    always @(posedge clk or negedge rst_sync) begin
        if (!rst_sync) begin
            sb_dp <= 1'b0;
        end else if (dut.w_d_hready) begin
            if (sb_dp) begin
                if (dut.w_d_hresp) n_err++;
                else if (sb_a[15:11] == 5'b10000) begin
                    if (sb_w) begin
                        ram_ref[sb_a[10:0]] = dut.w_d_hwdata; ram_known[sb_a[10:0]] = 1'b1;
                        n_ram_wr++;
                    end else begin
                        if (ram_known[sb_a[10:0]] && dut.w_d_hrdata !== ram_ref[sb_a[10:0]])
                            fail($sformatf("RAM read %04h = %02h, expected %02h",
                                           sb_a, dut.w_d_hrdata, ram_ref[sb_a[10:0]]));
                        ram_ref[sb_a[10:0]] = dut.w_d_hrdata; ram_known[sb_a[10:0]] = 1'b1;
                        n_ram_rd++;
                    end
                end else if (sb_a[15:13] == 3'b000) begin
                    if (!sb_w) begin
                        logic [7:0] e;
                        e = sb_a[0] ? rom_ref[sb_a[12:1]][15:8] : rom_ref[sb_a[12:1]][7:0];
                        if (dut.w_d_hrdata !== e)
                            fail($sformatf("ROM read %04h = %02h, expected %02h", sb_a, dut.w_d_hrdata, e));
                        n_rom_rd++;
                    end
                end else if (sb_a[15:12] == 4'hF) n_uart_acc++;
            end
            sb_dp <= dut.w_d_htrans[1];
            sb_a  <= dut.w_d_haddr;
            sb_w  <= dut.w_d_hwrite;
        end
    end

    // ------------------------------------ cache <-> DRAM controller, DRAM pins
    int unsigned n_rd_cmd = 0, n_wr_cmd = 0, n_commit = 0, n_ack = 0;
    wire [4:0] w_opcode = {csn, actn, a[16], a[15], a[14]};
    always @(posedge ck_t) begin
        if (w_opcode == 5'b01101) n_rd_cmd++;
        if (w_opcode == 5'b01100) n_wr_cmd++;
        if (`SOC8_MODEL.data_write === 1'b1) n_commit++;
    end
    always @(posedge clk) begin
        if (dut.w_mem_ack === 1'b1) begin
            n_ack++;
            if (!rst_sync) fail("DRAM ack during reset");
            if (!(dut.u_cache.r_state == 2'd1 || dut.u_cache.r_state == 2'd2))
                fail("DRAM ack while the cache waits for none");
            if (dut.u_dram_ctrl.r_addr[10:3] !== dut.w_mem_address ||
                dut.u_dram_ctrl.r_write !== dut.w_mem_write)
                fail($sformatf("DRAM ack for another request: ctrl %h/%b cache %h/%b",
                     dut.u_dram_ctrl.r_addr[10:3], dut.u_dram_ctrl.r_write,
                     dut.w_mem_address, dut.w_mem_write));
        end
        if (dut.u_dram_ctrl.r_dq_oe === 1'b1 && `SOC8_MODEL.dq_oe === 1'b1) fail("DQ contention");
    end

    // ----------------------------------------------------- interrupt entries
    int unsigned irq_entries = 0;
    reg irq_active_d = 1'b0;
    always @(posedge clk) begin
        if (irq_active === 1'b1 && irq_active_d !== 1'b1) irq_entries++;
        irq_active_d <= irq_active;
    end

    // ---------------------------------------------------------------- helpers
    string prog_dir;

    task automatic load_program(input string name);
        int fd;
        string path;
        path = {prog_dir, "/", name, ".mem"};
        fd = $fopen(path, "r");
        if (fd == 0) begin fail({"missing program image ", path}); return; end
        $fclose(fd);
        for (int i = 0; i < 4096; i++) rom_ref[i] = 16'h0000;
        $readmemh(path, rom_ref);
        for (int i = 0; i < 4096; i++) dut.u_rom.r_mem[i] = rom_ref[i];
    endtask

    // Counters that a test checks start from the reset assertion.
    task automatic clear_counts();
        tx_q.delete();
        n_ram_rd = 0; n_ram_wr = 0; n_rom_rd = 0; n_uart_acc = 0; n_err = 0;
        n_rd_cmd = 0; n_wr_cmd = 0; n_commit = 0; n_ack = 0; irq_entries = 0;
    endtask

    task automatic start_program(input string name);
        @(negedge clk);
        rst_n_raw = 1'b0;
        #20;
        load_program(name);
        clear_counts();
        #30;
        rst_n_raw = 1'b1;
        @(posedge rst_sync);
    endtask

    task automatic wait_halt(input int unsigned max_cycles, input string name);
        int unsigned c = 0;
        while (c < max_cycles && halted !== 1'b1) begin @(posedge clk); c++; end
        if (halted !== 1'b1) fail({name, ": no HALT"});
    endtask

    task automatic wait_tx(input int unsigned n, input real max_ns);
        real t0;
        t0 = $realtime;
        while (tx_q.size() < n && $realtime - t0 < max_ns) #(BIT_NS);
    endtask

    task automatic check_tx(input string name, input logic [7:0] exp [$]);
        if (tx_q.size() != exp.size())
            fail($sformatf("%s: %0d UART bytes, expected %0d", name, tx_q.size(), exp.size()));
        for (int i = 0; i < exp.size() && i < tx_q.size(); i++)
            if (tx_q[i] !== exp[i])
                fail($sformatf("%s: UART byte %0d = %02h, expected %02h", name, i, tx_q[i], exp[i]));
    endtask

    // Valid cache lines + model array against the reference (known bytes).
    task automatic check_contents(input string name);
        int unsigned bad = 0;
        for (int b = 0; b < 2048; b++) begin
            int l, idx, tg;
            logic [63:0] ln;
            if (!ram_known[b]) continue;
            l = b >> 3; idx = l % 8; tg = l >> 3;
            if (dut.u_cache.r_valid[idx] && dut.u_cache.r_tag[idx] == tg) ln = dut.u_cache.r_data[idx];
            else ln = `SOC8_MODEL_LINE(l);
            if (ln[(b % 8) * 8 +: 8] !== ram_ref[b]) begin
                bad++;
                if (bad <= 5) fail($sformatf("%s: RAM byte %03h = %02h, expected %02h",
                                             name, b, ln[(b % 8) * 8 +: 8], ram_ref[b]));
            end
        end
    endtask

    function automatic logic [7:0] ram_basic_sum();
        logic [7:0] s = 8'h00;
        for (int i = 0; i < 256; i++) s += 8'(3 + 7 * i);
        return s;
    endfunction

    // ------------------------------------------------------------------ tests
    int unsigned n_tests = 0, total_tx = 0, total_irq = 0, total_resets = 0;
    int unsigned cov_rst_read = 0, cov_rst_write = 0, cov_rst_other = 0, cov_rst_short = 0;

    task automatic check_ram_basic_result(input string name, input bit counters);
        logic [7:0] exp [$];
        wait_halt(400000, name);
        wait_tx(5, 80 * BIT_NS);
        if (fault !== 1'b0) fail($sformatf("%s: fault code %0d at %04h", name, fault_code, pc));
        exp.push_back(ram_basic_sum());
        exp.push_back(8'h12); exp.push_back(8'h34); exp.push_back(8'h56); exp.push_back(8'h78);
        check_tx(name, exp);
        if (n_ram_wr != 256 || n_ram_rd != 256 || n_rom_rd != 4 || n_err != 0)
            fail($sformatf("%s: RAM writes %0d reads %0d, ROM reads %0d, errors %0d",
                           name, n_ram_wr, n_ram_rd, n_rom_rd, n_err));
        if (err_cnt != 0) fail($sformatf("%s: bus error count %0d", name, err_cnt));
        if (counters) begin
            if (n_acc != 512 || n_miss != 64 || n_wb != 32)
                fail($sformatf("%s: cache accesses %0d misses %0d write-backs %0d, expected 512/64/32",
                               name, n_acc, n_miss, n_wb));
            if (n_miss != 16'(n_rd_cmd) || n_wb != 16'(n_wr_cmd) || n_wr_cmd != n_commit)
                fail($sformatf("%s: misses %0d RD %0d, write-backs %0d WR %0d commits %0d",
                               name, n_miss, n_rd_cmd, n_wb, n_wr_cmd, n_commit));
        end
        check_contents(name);
        total_tx += tx_q.size();
    endtask

    task automatic test_ram_basic();
        start_program("ram_basic");
        check_ram_basic_result("ram_basic", 1'b1);
        n_tests++;
        $display("CASE ram_basic accesses=%0d misses=%0d writebacks=%0d RD=%0d WR=%0d sum=%02h",
                 n_acc, n_miss, n_wb, n_rd_cmd, n_wr_cmd, ram_basic_sum());
    endtask

    // sender: sender clock relative to nominal (1.0, 1.015 = 1.5% fast, ...).
    task automatic test_uart_echo_irq(input int unsigned n, input real sender);
        logic [7:0] sent [$], exp [$];
        string name;
        name = $sformatf("uart_echo_irq(sender x%0.3f)", sender);
        start_program("uart_echo_irq");
        repeat (300) @(posedge clk);
        for (int i = 0; i < n; i++) begin
            logic [7:0] b;
            case (i)
                0: b = 8'h00;  1: b = 8'hFF;  2: b = 8'h55;  3: b = 8'hAA;
                default: b = 8'($urandom);
            endcase
            sent.push_back(b);
            send_byte(b, BIT_NS / sender);
            if (i >= n / 2) #(BIT_NS * $urandom_range(3));   // first half back to back
        end
        exp.push_back(8'h00);
        for (int i = 0; i + 1 < n; i++) exp.push_back(sent[i]);
        wait_tx(n, 40 * BIT_NS);
        repeat (2000) @(posedge clk);                     // room for a spurious entry
        check_tx(name, exp);
        if (irq_entries != n) fail($sformatf("%s: %0d handler entries for %0d bytes", name, irq_entries, n));
        if (irq !== 1'b0 || irq_active !== 1'b0) fail({name, ": IRQ or handler still active at the end"});
        if (halted !== 1'b0 || fault !== 1'b0) fail({name, ": CPU stopped"});
        if (n_err != 0 || err_cnt != 0) fail({name, ": bus error"});
        if (dut.u_uart.w_fe || dut.u_uart.w_pe || dut.u_uart.w_oe) fail({name, ": UART error flag set"});
        // IRQ_EN write once, then TX_DATA push + RX_DATA pop per entry.
        if (n_uart_acc != 1 + 2 * n)
            fail($sformatf("%s: %0d UART register accesses, expected %0d", name, n_uart_acc, 1 + 2 * n));
        n_tests++; total_tx += tx_q.size(); total_irq += irq_entries;
        $display("CASE %s bytes=%0d entries=%0d uart_accesses=%0d", name, n, irq_entries, n_uart_acc);
    endtask

    task automatic test_fault_unmapped();
        logic [7:0] exp [$];
        start_program("fault_unmapped");
        wait_halt(20000, "fault_unmapped");
        wait_tx(1, 20 * BIT_NS);
        if (fault !== 1'b1 || fault_code != 3'd3)
            fail($sformatf("fault_unmapped: fault=%b code=%0d", fault, fault_code));
        if (rom_ref[pc][15:10] != 6'h04) fail($sformatf("fault_unmapped: stopped at %04h, not the LD", pc));
        if (err_addr != 16'h4000 || err_cnt != 16'd1)
            fail($sformatf("fault_unmapped: bus error address %04h count %0d", err_addr, err_cnt));
        if (n_err != 1) fail($sformatf("fault_unmapped: %0d ERROR completions", n_err));
        exp.push_back(8'h41);
        check_tx("fault_unmapped", exp);
        n_tests++; total_tx += tx_q.size();
        $display("CASE fault_unmapped code=%0d pc=%04h err_addr=%04h", fault_code, pc, err_addr);
    endtask

    task automatic test_fault_rom_write();
        logic [7:0] exp [$];
        start_program("fault_rom_write");
        wait_halt(20000, "fault_rom_write");
        repeat (200) @(posedge clk);
        if (fault !== 1'b1 || fault_code != 3'd3)
            fail($sformatf("fault_rom_write: fault=%b code=%0d", fault, fault_code));
        if (rom_ref[pc][15:10] != 6'h05) fail($sformatf("fault_rom_write: stopped at %04h, not the ST", pc));
        if (err_cnt != 16'd0) fail("fault_rom_write: default slave counted the ROM error");
        if (n_err != 1) fail($sformatf("fault_rom_write: %0d ERROR completions", n_err));
        if (dut.u_rom.r_mem[8] !== rom_ref[8]) fail("fault_rom_write: ROM word changed");
        check_tx("fault_rom_write", exp);
        n_tests++;
        $display("CASE fault_rom_write code=%0d pc=%04h", fault_code, pc);
    endtask

    task automatic test_reset_mid_run(input int unsigned k);
        start_program("ram_basic");
        for (int r = 0; r < k; r++) begin
            int unsigned st;
            repeat ($urandom_range(9000, 200)) @(posedge clk);
            if ($urandom_range(1)) begin
                int unsigned c = 0;
                while (dut.u_cache.r_state == 2'd0 && c < 20000) begin @(posedge clk); c++; end
                repeat ($urandom_range(150)) @(posedge clk);
            end
            #($urandom_range(999) / 100.0);
            st = dut.u_dram_ctrl.r_state;
            if (st == 7) cov_rst_read++; else if (st == 11) cov_rst_write++; else cov_rst_other++;
            rst_n_raw = 1'b0;
            if ($urandom_range(3) == 0) begin #($urandom_range(9, 3) / 10.0); cov_rst_short++; end
            else #($urandom_range(400, 10));
            clear_counts();
            rst_n_raw = 1'b1;
            total_resets++;
            @(posedge rst_sync);
        end
        // A drain finished after the release may add a commit; the command
        // counters are not compared here.
        check_ram_basic_result("reset_mid_run", 1'b0);
        n_tests++;
        $display("CASE reset_mid_run resets=%0d in_read=%0d in_write=%0d other=%0d short=%0d",
                 k, cov_rst_read, cov_rst_write, cov_rst_other, cov_rst_short);
    endtask

    // ------------------------------------------------ calculator (firmware)
    // Reference of 02_design/calculator.md, written here from the spec.
    bit ref_ok = 1'b0;
    int ref_a = 0, ref_b = 0;

    function automatic bit is_digit(input byte c);
        return c >= "0" && c <= "9";
    endfunction
    function automatic bit is_letter(input byte c);
        return (c >= "A" && c <= "Z") || (c >= "a" && c <= "z");
    endfunction

    // Reply expected for one line (terminator excluded); "" = no reply.
    function automatic string ref_reply(input string s, input bit uart_err);
        int n;
        n = s.len();
        if (uart_err) return "ERR SYNTAX";
        if (n == 0) return "";
        if (n > 15) return "ERR SYNTAX";
        if (is_letter(s[0])) begin
            string u;
            if (n != 3) return "ERR SYNTAX";
            for (int i = 0; i < n; i++) if (!is_letter(s[i])) return "ERR SYNTAX";
            u = s.toupper();
            if (u != "ADD" && u != "SUB" && u != "MUL" && u != "DIV") return "ERR SYNTAX";
            if (!ref_ok) return "ERR NOARG";
            if (u == "ADD") return $sformatf("ADD:%0d", ref_a + ref_b);
            if (u == "SUB") return $sformatf("SUB:%0d", ref_a - ref_b);
            if (u == "MUL") return $sformatf("MUL:%0d", ref_a * ref_b);
            if (ref_b == 0) return "ERR DIV0";
            return $sformatf("DIV Q:%0d R:%0d", ref_a / ref_b, ref_a % ref_b);
        end
        if (s[0] == "-" || is_digit(s[0])) begin
            int i, v[2];
            bit rng;
            i = 0; rng = 1'b0;
            for (int k = 0; k < 2; k++) begin
                bit neg;
                int nd, mag;
                neg = 1'b0; nd = 0; mag = 0;
                if (i < n && s[i] == "-") begin neg = 1'b1; i++; end
                while (i < n && is_digit(s[i])) begin mag = mag * 10 + (s[i] - "0"); nd++; i++; end
                if (nd < 1 || nd > 3) return "ERR SYNTAX";
                if (k == 0) begin
                    if (i >= n || s[i] != ",") return "ERR SYNTAX";
                    i++;
                end else if (i != n) return "ERR SYNTAX";
                if ((!neg && mag > 127) || (neg && mag > 128)) rng = 1'b1;
                v[k] = neg ? -mag : mag;
            end
            if (rng) return "ERR RANGE";
            ref_a = v[0]; ref_b = v[1]; ref_ok = 1'b1;
            return "";
        end
        return "ERR SYNTAX";
    endfunction

    int unsigned calc_chars = 0, calc_lines = 0, calc_replies = 0, calc_errors = 0;

    // Send a line and its terminator (0: CRLF, 1: CR, 2: LF); bad_at >= 0
    // sends that character with a parity error.
    task automatic send_line(input string s, input int term, input int bad_at = -1);
        for (int i = 0; i < s.len(); i++) begin
            send_byte(s[i], BIT_NS, i == bad_at);
            calc_chars++;
        end
        if (term != 2) begin send_byte(8'h0D, BIT_NS); calc_chars++; end
        if (term != 1) begin send_byte(8'h0A, BIT_NS); calc_chars++; end
    endtask

    // Next reply line from TX (CRLF removed); "" after the timeout.
    task automatic get_reply(output string r, input real max_ns);
        real t0;
        int k;
        t0 = $realtime;
        r = "";
        forever begin
            k = -1;
            for (int i = 0; i + 1 < tx_q.size(); i++)
                if (tx_q[i] == 8'h0D && tx_q[i + 1] == 8'h0A) begin k = i; break; end
            if (k >= 0 || $realtime - t0 >= max_ns) break;
            #(BIT_NS);
        end
        if (k < 0) return;
        for (int i = 0; i < k; i++) r = {r, string'(tx_q[i])};
        repeat (k + 2) void'(tx_q.pop_front());
    endtask

    // One line: reference reply, send, and check the reply if one is due.
    task automatic calc_step(input string s, input int term, input int bad_at = -1);
        string e, r;
        e = ref_reply(s, bad_at >= 0);
        send_line(s, term, bad_at);
        calc_lines++;
        if (e != "") begin
            get_reply(r, 400 * BIT_NS);
            calc_replies++;
            if (e.substr(0, 2) == "ERR") calc_errors++;
            if (r != e) fail($sformatf("calc: line \"%s\": reply \"%s\", expected \"%s\"", s, r, e));
        end
    endtask

    task automatic test_calc(input bit with_random);
        string dir [$], bursts [$], e [$];
        int t;
        ref_ok = 1'b0;
        calc_chars = 0; calc_lines = 0; calc_replies = 0; calc_errors = 0;
        start_program("calc");
        repeat (300) @(posedge clk);
        // Directed lines: calculator.md section 5 and boundary cases.
        dir = '{"ADD", "10,20", "ADD", "SUB", "MUL", "DIV", "20,10", "DIV",
                "-128,-128", "MUL", "-128,-1", "DIV", "-128,127", "MUL", "ADD", "SUB",
                "127,-128", "SUB", "ADD", "-7,2", "DIV", "7,-2", "DIV", "-7,-2", "DIV",
                "-127,2", "DIV", "-128,-3", "DIV", "10,0", "DIV", "MUL", "ADD",
                "200,1", "ADD", "-129,0", "1,128", "128,1", "10 ,20", "1020", "ADDX", "AD", "A",
                "1234,1", "5,", "-", "--5,1", "5,--1", "5,1,2", "+5,1", "5-3,1",
                "0000000000000000", "add", "Sub", "mUl", "007,-0", "DIV", "SUB", "",
                "99,99", "MUL", "0,-5", "DIV", "MUL"};
        t = 0;
        foreach (dir[i]) begin calc_step(dir[i], t); t = (t + 1) % 3; end
        // Back-to-back lines without waiting, then all replies.
        bursts = '{"5,6", "ADD", "SUB", "MUL", "DIV"};
        foreach (bursts[i]) begin
            string x;
            x = ref_reply(bursts[i], 1'b0);
            if (x != "") e.push_back(x);
            send_line(bursts[i], 0);
            calc_lines++;
        end
        foreach (e[i]) begin
            string r;
            get_reply(r, 400 * BIT_NS);
            calc_replies++;
            if (r != e[i]) fail($sformatf("calc burst: reply %0d \"%s\", expected \"%s\"", i, r, e[i]));
        end
        // A receive (parity) error inside a line: ERR SYNTAX, A and B kept.
        calc_step("10,20", 0, 4);
        calc_step("ADD", 0);
        if (with_random) begin
            for (int i = 0; i < 120; i++) begin
                int p;
                string s;
                p = $urandom_range(99);
                if (p < 45) s = $sformatf("%0d,%0d", $signed(8'($urandom)), $signed(8'($urandom)));
                else if (p < 85) begin
                    string ops [4];
                    ops = '{"add", "sub", "mul", "div"};
                    s = ops[$urandom_range(3)];
                    if ($urandom_range(1)) s = s.toupper();
                end else if (p < 92) s = $sformatf("%0d,%0d", $urandom_range(400, 128), $signed(8'($urandom)));
                else begin
                    string bad [6];
                    bad = '{"1,2,3", "ab", "12a,1", "-,4", "MULT", "4 ,4"};
                    s = bad[$urandom_range(5)];
                end
                calc_step(s, $urandom_range(2));
            end
        end
        repeat (2000) @(posedge clk);
        if (tx_q.size() != 0) fail($sformatf("calc: %0d unexpected TX bytes at the end", tx_q.size()));
        if (irq_entries != calc_chars)
            fail($sformatf("calc: %0d handler entries for %0d characters", irq_entries, calc_chars));
        if (halted !== 1'b0 || fault !== 1'b0) fail("calc: CPU stopped");
        if (n_err != 0 || err_cnt != 0) fail("calc: bus error");
        if (dut.u_uart.w_fe || dut.u_uart.w_pe || dut.u_uart.w_oe) fail("calc: UART error flag left set");
        n_tests++; total_irq += irq_entries;
        $display("CASE calc lines=%0d chars=%0d replies=%0d error_replies=%0d entries=%0d random=%0d",
                 calc_lines, calc_chars, calc_replies, calc_errors, irq_entries, with_random);
    endtask

    initial begin
        if (!$value$plusargs("PROG_DIR=%s", prog_dir)) prog_dir = ".";
        test_ram_basic();
        if (FULL) begin
            test_uart_echo_irq(40, 1.0);
            test_uart_echo_irq(24, 1.015);
            test_uart_echo_irq(24, 0.985);
            test_fault_unmapped();
            test_fault_rom_write();
            test_reset_mid_run(20);
            test_calc(1'b1);
        end else begin
            test_uart_echo_irq(8, 1.0);
            test_uart_echo_irq(8, 1.015);
            test_calc(1'b0);
        end
        fails += chk_bus.fails + chk_ram.fails + chk_apb.fails;
        $display("COVER tests=%0d uart_tx=%0d irq_entries=%0d resets=%0d rst_in_read=%0d rst_in_write=%0d rst_short=%0d",
                 n_tests, total_tx, total_irq, total_resets, cov_rst_read, cov_rst_write, cov_rst_short);
        if (fails == 0)
            $display("SOC8_TOP_PASS baud=%0d tests=%0d uart_tx=%0d irq_entries=%0d resets=%0d",
                     BAUD, n_tests, total_tx, total_irq, total_resets);
        else
            $display("SOC8_TOP_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #100ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
`undef SOC8_MODEL
`undef SOC8_MODEL_LINE
