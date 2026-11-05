`timescale 1ns/1ps
// Board-level TB for soc8_zybo_top (fpga/boards/zybo): the pins only.
//   125 MHz on i_clk125 -> MMCM (unisim model) -> 100 MHz SoC + BRAM-based
//   DRAM model; BTN0 reset; UART 115200 bps 8E1 driver on i_uart_rxd and
//   receiver on o_uart_txd; LEDs. ROM image: read by the SoC ROM from
//   ROM_FILE (relative to the xsim run folder).
// PROG=0 (calc.mem, the calculator firmware), checks:
//   - MMCM output period 10.000 ns after LOCKED; LED[0] (reset released) is
//     0 while BTN0 is pressed and 1 after; LED[1] (DRAM initialized) comes up
//     after each reset; LED[2] (halt) and LED[3] (fault) never light.
//   - Calculator replies for the 02_design/calculator.md section 5 cases
//     (errors included, the 17-byte DIV reply, A/B kept after ERR RANGE),
//     sent at the protocol pace (wait for each operation reply), compared
//     with the replies written here from the protocol.
//   - After a BTN0 reset in the middle, A/B are gone (ERR NOARG).
//   - Every TX frame has the right parity and stop bit.
//   The calculator keeps its 25 RAM bytes in the cache and writes each one
//   before reading it, so it does not test the DRAM data path. PROG=1 does.
// PROG=1 (ram_basic.mem, tb/soc/programs/ram_basic.asm), checks:
//   - 256 bytes (4 x the cache) written and read back through the cache,
//     the DRAM controller and the BRAM model: UART bytes 80 12 34 56 78
//     (sum low byte, then the ROM table), then HALT (LED[2] on, LED[3] off).
//   - The model array holds v(i) = 3 + 7i for all 256 bytes (every line was
//     written back at least once).
// Prints BOARD_TOP_PASS only if no check failed.
module tb_soc8_zybo_top;
    parameter integer PROG = 0;
    parameter ROM_FILE = (PROG == 1) ? "ram_basic.mem" : "calc.mem";
    localparam real BIT_NS = 1.0e9 / 115200.0;

    reg clk125 = 1'b0, btn = 1'b1, rxd = 1'b1;
    always #4 clk125 = ~clk125;
    wire txd;
    wire [3:0] led;

    soc8_zybo_top #(.ROM_FILE(ROM_FILE)) dut (
        .i_clk125(clk125), .i_btn_rst(btn), .i_uart_rxd(rxd), .o_uart_txd(txd), .o_led(led));

    int unsigned fails = 0, n_lines = 0, n_replies = 0, n_resets = 0, n_rx_bytes = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // ------------------------------------------------ LED and clock checks
    always @(posedge led[2]) if (PROG == 0 && !$isunknown(led[2])) fail("LED[2]: CPU halted");
    always @(posedge led[3]) if (!$isunknown(led[3])) fail("LED[3]: CPU fault");

    task automatic check_clock();
        realtime t0, t1;
        wait (dut.w_locked === 1'b1);
        @(posedge dut.w_clk100); t0 = $realtime;
        repeat (100) @(posedge dut.w_clk100); t1 = $realtime;
        if ((t1 - t0) / 100.0 < 9.999 || (t1 - t0) / 100.0 > 10.001)
            fail($sformatf("SoC clock period %f ns, expected 10.000", (t1 - t0) / 100.0));
        else $display("CLOCK soc_period_ns=%0.3f locked=1", (t1 - t0) / 100.0);
    endtask

    // Press BTN0, check LED[0] low, release, wait for reset release and DRAM.
    task automatic press_reset(input int unsigned hold_ns);
        btn = 1'b1;
        #(hold_ns);
        if (led[0] !== 1'b0) fail("LED[0] not 0 while BTN0 is pressed");
        if (led[1] !== 1'b0) fail("LED[1] not 0 while BTN0 is pressed");
        btn = 1'b0;
        fork
            begin wait (led[0] === 1'b1 && led[1] === 1'b1); end
            begin #(100_000); fail("no reset release / DRAM initialized within 100 us"); end
        join_any
        disable fork;
        n_resets++;
    endtask

    // ------------------------------------------------ UART (8E1)
    byte rx_q[$];
    initial forever begin : receiver
        byte b;
        bit p;
        @(negedge txd);
        #(BIT_NS / 2);
        if (txd !== 1'b0) continue;                 // not a start bit
        for (int i = 0; i < 8; i++) begin #(BIT_NS); b[i] = txd; end
        #(BIT_NS); p = txd;
        #(BIT_NS);
        if (txd !== 1'b1) fail("TX stop bit");
        if (p !== ^b) fail($sformatf("TX parity of %02h", b));
        rx_q.push_back(b);
        n_rx_bytes++;
    end

    task automatic send_byte(input byte b);
        rxd = 1'b0; #(BIT_NS);
        for (int i = 0; i < 8; i++) begin rxd = b[i]; #(BIT_NS); end
        rxd = ^b; #(BIT_NS);                        // even parity
        rxd = 1'b1; #(BIT_NS);
    endtask

    task automatic send_line(input string s);
        for (int i = 0; i < s.len(); i++) send_byte(s[i]);
        send_byte(8'h0D); send_byte(8'h0A);
        n_lines++;
    endtask

    // One reply line (CRLF removed); at most 4 ms for the whole line.
    task automatic get_line(output string s);
        int unsigned waited = 0;
        byte b;
        s = "";
        forever begin
            while (rx_q.size() == 0) begin
                #(1000); waited++;
                if (waited > 4000) begin fail($sformatf("reply timeout after \"%s\"", s)); return; end
            end
            b = rx_q.pop_front();
            if (b == 8'h0D) begin
                while (rx_q.size() == 0) begin
                    #(1000); waited++;
                    if (waited > 4000) begin fail("no LF after CR"); return; end
                end
                b = rx_q.pop_front();
                if (b != 8'h0A) fail($sformatf("byte after CR is %02h, expected 0A", b));
                return;
            end
            s = $sformatf("%s%c", s, b);
        end
    endtask

    // Operation line and its expected reply (the protocol pace).
    task automatic op(input string line, input string exp);
        string got;
        send_line(line);
        get_line(got);
        n_replies++;
        if (got != exp) fail($sformatf("\"%s\" -> \"%s\", expected \"%s\"", line, got, exp));
    endtask

    // PROG=1: RAM write/read through the DRAM path, then HALT.
    task automatic ram_test();
        byte exp [5] = '{8'h80, 8'h12, 8'h34, 8'h56, 8'h78};
        int unsigned waited = 0, bad = 0;
        while (rx_q.size() < 5 && waited < 20000) begin #(1000); waited++; end
        if (rx_q.size() < 5) fail($sformatf("ram_basic: %0d UART bytes, expected 5", rx_q.size()));
        for (int i = 0; i < 5 && rx_q.size() > 0; i++) begin
            byte b;
            b = rx_q.pop_front();
            if (b !== exp[i]) fail($sformatf("ram_basic: UART byte %0d = %02h, expected %02h", i, b, exp[i]));
        end
        fork
            begin wait (led[2] === 1'b1); end
            begin #(100_000); fail("ram_basic: no HALT (LED[2]) within 100 us"); end
        join_any
        disable fork;
        if (led[3] !== 1'b0) fail("ram_basic: LED[3] (fault) on");
        for (int b = 0; b < 256; b++)
            if (dut.u_dram.mem[b / 8][(b % 8) * 8 +: 8] !== 8'(3 + 7 * b)) begin
                bad++;
                if (bad <= 5) fail($sformatf("ram_basic: DRAM model byte %02h = %02h, expected %02h",
                                             b, dut.u_dram.mem[b / 8][(b % 8) * 8 +: 8], 8'(3 + 7 * b)));
            end
        n_replies = 5;
    endtask

    initial begin
        check_clock();
        press_reset(2_000);                         // power-up press
        if (PROG == 1) begin
            ram_test();
            #(200_000);
            if (rx_q.size() != 0) fail("ram_basic: extra TX bytes");
            $display("COVER mode=ram tx_bytes=%0d resets=%0d dram_bytes_checked=256", n_rx_bytes, n_resets);
            if (fails == 0) $display("BOARD_TOP_PASS mode=ram tx_bytes=%0d resets=%0d", n_rx_bytes, n_resets);
            else $display("BOARD_TOP_FAIL failures=%0d", fails);
            $finish;
        end
        op("ADD", "ERR NOARG");
        send_line("10,20");
        op("ADD", "ADD:30");
        op("sub", "SUB:-10");
        op("Mul", "MUL:200");
        op("DIV", "DIV Q:0 R:10");
        send_line("20,10");     op("DIV", "DIV Q:2 R:0");
        send_line("-128,-128"); op("MUL", "MUL:16384");
        send_line("-128,-1");   op("DIV", "DIV Q:128 R:0");
        send_line("-7,2");      op("DIV", "DIV Q:-3 R:-1");
        send_line("-120,11");   op("DIV", "DIV Q:-10 R:-10");   // 17 bytes with CRLF
        send_line("10,0");      op("DIV", "ERR DIV0");
        op("200,1", "ERR RANGE");
        op("ADD", "ADD:10");                        // A/B kept (10, 0)
        op("10 ,20", "ERR SYNTAX");
        op("ADDX", "ERR SYNTAX");
        if (rx_q.size() != 0) fail("extra TX bytes");
        // Reset with BTN0 in the middle: A/B are cleared by the firmware.
        #(20_000);
        press_reset(1_000);
        op("ADD", "ERR NOARG");
        send_line("7,-2");      op("DIV", "DIV Q:-3 R:1");
        #(200_000);
        if (rx_q.size() != 0) fail("extra TX bytes at the end");
        if (led[0] !== 1'b1 || led[1] !== 1'b1) fail("LED[0]/LED[1] not on at the end");
        $display("COVER mode=calc lines=%0d replies=%0d tx_bytes=%0d resets=%0d", n_lines, n_replies, n_rx_bytes, n_resets);
        if (fails == 0)
            $display("BOARD_TOP_PASS mode=calc lines=%0d replies=%0d tx_bytes=%0d resets=%0d", n_lines, n_replies, n_rx_bytes, n_resets);
        else
            $display("BOARD_TOP_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #200ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
