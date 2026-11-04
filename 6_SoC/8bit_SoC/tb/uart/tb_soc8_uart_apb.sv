`timescale 1ns/1ps
// Unit TB for soc8_uart_apb (M9), through the real AHB-to-APB3 bridge:
//   ahb_lite_master_bfm -> ahb_apb_bridge (M8) -> soc8_uart_apb -> uart_top
// with a serial model on the UART pins (8E1; 100 MHz clock and 3.125 Mbaud,
// so 32 clocks per bit and 352 per frame).
// Checks (reference rules written here):
//   - Every APB ACCESS cycle: PREADY=1; PSLVERR iff wrong direction,
//     unmapped PADDR, RX empty or TX full; STATUS read = live UART status
//     bits; IRQ_EN read = TB copy of the last write; RX pop, TX push and flag
//     clear strobes only for successful transfers.
//   - Every completed AHB transfer equals the APB result (bridge path).
//   - Serial: bytes on TXD equal the successful TX_DATA writes, in order,
//     with even parity and a stop bit; RX_DATA reads equal the bytes sent on
//     RXD, in order, except the byte dropped by an overrun.
//   - IRQ every cycle = registered (status & IRQ_EN), IRQ_EN taken from the
//     APB writes; directed rise and fall per source (RX, TX empty, parity,
//     frame and overrun errors each alone).
//   - ERROR_CLEAR clears exactly the written flags; reset clears all state.
//   - Back-to-back RX frames (no idle bit) with the sender clock nominal,
//     2% fast and 2% slow: every byte received, no error flag.
//   - SVA: APB master rules and the bridge AHB response rules.
// Prints UART_APB_PASS only if no check failed and every coverage count is
// at least 1.
module tb_soc8_uart_apb;
    localparam integer BIT = 32;                     // clocks per UART bit
    localparam integer DEPTH = 16;                   // FIFO depth
    localparam [15:0] RX = 16'hFF00, TX = 16'hFF01, ST = 16'hFF02, EC = 16'hFF03, IE = 16'hFF04;

    reg clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;
    reg rxd = 1'b1;
    wire txd, irq;

    wire [15:0] haddr;
    wire [1:0]  htrans;
    wire        hwrite;
    wire [2:0]  hsize;
    wire [7:0]  hwdata, hrdata;
    wire        hready, hresp;
    wire        psel, penable, pwrite, pready, pslverr;
    wire [11:0] paddr;
    wire [7:0]  pwdata, prdata;

    ahb_lite_master_bfm bfm (
        .clk(clk), .rstn(rstn), .haddr(haddr), .htrans(htrans), .hwrite(hwrite),
        .hsize(hsize), .hwdata(hwdata), .hrdata(hrdata), .hready(hready), .hresp(hresp));

    // Point-to-point for this TB: every transfer goes to the bridge.
    ahb_apb_bridge bridge (
        .i_clk(clk), .i_rstn(rstn),
        .i_hsel(1'b1), .i_haddr(haddr), .i_htrans(htrans), .i_hwrite(hwrite),
        .i_hsize(hsize), .i_hwdata(hwdata), .i_hready(hready),
        .o_hreadyout(hready), .o_hresp(hresp), .o_hrdata(hrdata),
        .o_psel(psel), .o_penable(penable), .o_paddr(paddr), .o_pwrite(pwrite),
        .o_pwdata(pwdata), .i_prdata(prdata), .i_pready(pready), .i_pslverr(pslverr));

    soc8_uart_apb #(.CLK_FREQ_HZ(100_000_000), .BAUD_RATE(3_125_000), .FIFO_DEPTH(DEPTH)) dut (
        .i_clk(clk), .i_rstn(rstn),
        .i_psel(psel), .i_penable(penable), .i_paddr(paddr), .i_pwrite(pwrite),
        .i_pwdata(pwdata), .o_prdata(prdata), .o_pready(pready), .o_pslverr(pslverr),
        .o_irq(irq), .o_uart_txd(txd), .i_uart_rxd(rxd));

    apb_checker chk_apb (
        .clk(clk), .rstn(rstn), .psel(psel), .penable(penable), .paddr(paddr),
        .pwrite(pwrite), .pwdata(pwdata), .pready(pready));
    // PREADY is always 1, so every OKAY bridge transfer waits exactly 2.
    ahb_lite_slave_checker #(.MAX_WAIT(2)) chk_ahb (
        .clk(clk), .rstn(rstn), .hsel(1'b1), .htrans(htrans),
        .hready(hready), .hreadyout(hready), .hresp(hresp));

    // Live UART core status (the core itself is verified by tb_uart).
    wire c_dr = dut.w_dr, c_thre = dut.w_thre, c_temt = dut.w_temt;
    wire c_fe = dut.w_fe, c_pe = dut.w_pe, c_oe = dut.w_oe, c_full = dut.w_tx_full;

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    function automatic bit exp_err(input logic [11:0] a, input bit w, input bit dr, input bit full);
        case (a)
            12'hF00: return w || !dr;
            12'hF01: return !w || full;
            12'hF02: return w;
            12'hF03: return !w;
            12'hF04: return 1'b0;
            default: return 1'b1;
        endcase
    endfunction

    // ---------------- APB-level model ----------------
    typedef struct {
        bit         err;
        bit         write;
        logic [7:0] rdata;
    } apb_t;
    apb_t apb_seq[$];
    logic [7:0] rx_read[$], rx_expect[$], tx_written[$], tx_seen[$];
    logic [2:0] tb_en = 3'b000;
    bit check_clr = 1'b1, clr_check_now = 1'b0;
    logic [2:0] clr_pending = 3'b000, clr_pre = 3'b000;
    int unsigned n_rx_ok = 0, n_rx_empty = 0, n_rx_wr = 0, n_tx_ok = 0, n_tx_full = 0, n_tx_rd = 0;
    int unsigned n_st = 0, n_st_wr = 0, n_ec = 0, n_ec_rd = 0, n_ie_wr = 0, n_ie_rd = 0, n_unmapped = 0;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tb_en <= 3'b000;
        end else if (psel && penable) begin
            logic [11:0] a;
            logic [7:0]  wd, rd, st;
            bit          w, e;
            apb_t        t;
            a = paddr; w = pwrite; wd = pwdata; rd = prdata;
            st = {1'b0, c_thre, c_pe, c_fe, c_oe, !c_temt, c_full, c_dr};
            e = exp_err(a, w, c_dr, c_full);
            if (!pready) fail("PREADY low");
            if (pslverr !== e)
                fail($sformatf("PADDR=%h W=%0d PSLVERR=%0d, expected %0d", a, w, pslverr, e));
            t.err = e; t.write = w; t.rdata = rd;
            apb_seq.push_back(t);
            if (e) begin
                if (a == 12'hF00 && !w) n_rx_empty++;
                else if (a == 12'hF00) n_rx_wr++;
                else if (a == 12'hF01 && w) n_tx_full++;
                else if (a == 12'hF01) n_tx_rd++;
                else if (a == 12'hF02) n_st_wr++;
                else if (a == 12'hF03) n_ec_rd++;
                else n_unmapped++;
            end else if (a == 12'hF00) begin
                rx_read.push_back(rd); n_rx_ok++;
            end else if (a == 12'hF01) begin
                tx_written.push_back(wd); n_tx_ok++;
            end else if (a == 12'hF02) begin
                n_st++;
                if (rd !== st) fail($sformatf("STATUS read %h, expected %h", rd, st));
            end else if (a == 12'hF03) begin
                n_ec++;
                clr_pending <= wd[5:3]; clr_pre <= {c_pe, c_fe, c_oe}; clr_check_now <= 1'b1;
            end else if (w) begin
                tb_en <= wd[2:0]; n_ie_wr++;
            end else begin
                n_ie_rd++;
                if (rd !== {5'b00000, tb_en}) fail($sformatf("IRQ_EN read %h, expected %h", rd, tb_en));
            end
        end
    end

    // ERROR_CLEAR: written flags are cleared, the others unchanged (directed part).
    always @(negedge clk) if (clr_check_now) begin
        if (check_clr && rstn) begin
            if ((clr_pending[0] ? c_oe : (c_oe != clr_pre[0])) ||
                (clr_pending[1] ? c_fe : (c_fe != clr_pre[1])) ||
                (clr_pending[2] ? c_pe : (c_pe != clr_pre[2])))
                fail($sformatf("ERROR_CLEAR %b: flags PE/FE/OE %b%b%b, before %b",
                     clr_pending, c_pe, c_fe, c_oe, clr_pre));
        end
        clr_check_now <= 1'b0;
    end

    // Strobes into the UART core: only in the ACCESS cycle of a good transfer.
    always @(negedge clk) if (rstn) begin
        bit       ere, ewe;
        logic [2:0] eclr;
        ere = psel && penable && !pwrite && paddr == 12'hF00 && c_dr;
        ewe = psel && penable && pwrite && paddr == 12'hF01 && !c_full;
        eclr = (psel && penable && pwrite && paddr == 12'hF03) ? pwdata[5:3] : 3'b000;
        if (dut.w_rhr_re !== ere || dut.w_thr_we !== ewe || dut.w_lsr_clr !== eclr)
            fail($sformatf("core strobes re/we/clr=%b%b%b expected %b%b%b",
                 dut.w_rhr_re, dut.w_thr_we, dut.w_lsr_clr, ere, ewe, eclr));
    end

    // IRQ = registered (status & IRQ_EN).
    reg exp_irq = 1'b0;
    always @(posedge clk or negedge rstn)
        if (!rstn) exp_irq <= 1'b0;
        else exp_irq <= (c_dr && tb_en[0]) || (c_thre && tb_en[1]) ||
                        ((c_oe || c_fe || c_pe) && tb_en[2]);
    always @(negedge clk) if (rstn && irq !== exp_irq)
        fail($sformatf("IRQ=%0d, expected %0d", irq, exp_irq));

    // ---------------- Serial models ----------------
    // RXD driver: one 8E1 frame plus one idle bit.
    task automatic send_byte(input logic [7:0] d, input bit bad_par = 1'b0,
                             input bit bad_stop = 1'b0, input bit keep = 1'b1);
        @(posedge clk);
        rxd <= 1'b0; repeat (BIT) @(posedge clk);
        for (int i = 0; i < 8; i++) begin rxd <= d[i]; repeat (BIT) @(posedge clk); end
        rxd <= (^d) ^ bad_par; repeat (BIT) @(posedge clk);
        rxd <= !bad_stop; repeat (BIT) @(posedge clk);
        rxd <= 1'b1; repeat (BIT) @(posedge clk);
        if (keep) rx_expect.push_back(d);
    endtask

    // RXD driver for back-to-back frames (no idle bit between them) from a
    // sender whose bit time is bit_ns (32 clocks = 320 ns is nominal), so the
    // sender clock can be faster or slower than the receiver's.
    int unsigned n_b2b = 0;
    task automatic send_burst(input int unsigned n, input real bit_ns);
        for (int i = 0; i < n; i++) begin
            logic [7:0] d;
            d = 8'($urandom);
            rxd = 1'b0; #(bit_ns);
            for (int j = 0; j < 8; j++) begin rxd = d[j]; #(bit_ns); end
            rxd = ^d; #(bit_ns);
            rxd = 1'b1; #(bit_ns);
            rx_expect.push_back(d);
            n_b2b++;
        end
        #(bit_ns);
    endtask

    // TXD monitor: samples mid-bit, checks parity and stop.
    bit tx_in_frame = 1'b0, tx_abort = 1'b0;
    int unsigned n_tx_frames = 0;
    always @(negedge rstn) if (tx_in_frame) tx_abort = 1'b1;
    initial forever begin
        logic [7:0] d;
        bit p, s;
        @(negedge txd);
        if (rstn) begin
            tx_in_frame = 1'b1; tx_abort = 1'b0;
            repeat (BIT / 2) @(posedge clk);
            for (int i = 0; i < 8; i++) begin repeat (BIT) @(posedge clk); d[i] = txd; end
            repeat (BIT) @(posedge clk); p = txd;
            repeat (BIT) @(posedge clk); s = txd;
            if (!tx_abort) begin
                if (p !== ^d) fail($sformatf("TX byte %h parity %0d", d, p));
                if (s !== 1'b1) fail($sformatf("TX byte %h stop bit 0", d));
                tx_seen.push_back(d); n_tx_frames++;
            end
            tx_in_frame = 1'b0; tx_abort = 1'b0;
        end
    end

    // ---------------- AHB access helpers ----------------
    task automatic acc(input logic [15:0] a, input bit w, input logic [7:0] wd,
                       output bit r, output logic [7:0] rd, input bit [2:0] sz = 3'b000);
        int unsigned n, id;
        n = bfm.results.size();
        id = bfm.push(a, w, wd, 0, sz);
        while (bfm.results.size() <= n) @(negedge clk);
        r = bfm.results[n].resp; rd = bfm.results[n].rdata;
    endtask
    task automatic ok(input logic [15:0] a, input bit w, input logic [7:0] wd);
        bit r; logic [7:0] rd;
        acc(a, w, wd, r, rd);
        if (r) fail($sformatf("HADDR=%h W=%0d got ERROR", a, w));
    endtask
    task automatic err(input logic [15:0] a, input bit w, input logic [7:0] wd);
        bit r; logic [7:0] rd;
        acc(a, w, wd, r, rd);
        if (!r) fail($sformatf("HADDR=%h W=%0d got OKAY, expected ERROR", a, w));
    endtask
    task automatic rd_is(input logic [15:0] a, input logic [7:0] exp);
        bit r; logic [7:0] rd;
        acc(a, 1'b0, 8'h00, r, rd);
        if (r || rd !== exp) fail($sformatf("read HADDR=%h resp=%0d data=%h, expected %h", a, r, rd, exp));
    endtask
    task automatic wait_cycles(input int n);
        repeat (n) @(negedge clk);
    endtask
    task automatic tx_drain();
        int unsigned t = 0;
        do begin @(negedge clk); t++; end while (!(c_temt && !tx_in_frame) && t < 100000);
        if (!c_temt) fail("TX did not drain");
        wait_cycles(4);
    endtask
    task automatic wait_idle();
        int unsigned t = 0;
        do begin @(negedge clk); t++; end while (!bfm.idle() && t < 100000);
        if (!bfm.idle()) fail("BFM did not finish (hang)");
        wait_cycles(2);
    endtask
    task automatic irq_is(input bit v, input string what);
        wait_cycles(3);
        if (irq !== v) fail($sformatf("IRQ %0d, expected %0d (%s)", irq, v, what));
    endtask

    function automatic bit same(ref logic [7:0] x[$], ref logic [7:0] y[$]);
        if (x.size() != y.size()) return 1'b0;
        for (int i = 0; i < x.size(); i++) if (x[i] !== y[i]) return 1'b0;
        return 1'b1;
    endfunction

    // Random register traffic (random phase).
    task automatic random_ops(input int n);
        repeat (n) begin
            int unsigned p, id;
            logic [15:0] a;
            bit w;
            bit [2:0] s;
            s = 3'b000;
            p = $urandom_range(99);
            if      (p < 25) begin a = RX; w = 1'b0; end
            else if (p < 28) begin a = RX; w = 1'b1; end
            else if (p < 43) begin a = TX; w = 1'b1; end
            else if (p < 46) begin a = TX; w = 1'b0; end
            else if (p < 66) begin a = ST; w = 1'b0; end
            else if (p < 68) begin a = ST; w = 1'b1; end
            else if (p < 73) begin a = EC; w = 1'b1; end
            else if (p < 75) begin a = EC; w = 1'b0; end
            else if (p < 80) begin a = IE; w = 1'b1; end
            else if (p < 88) begin a = IE; w = 1'b0; end
            else begin
                a = $urandom_range(1) ? 16'hF000 + 16'($urandom_range(16'h0EFF, 0))
                                      : 16'hFF05 + 16'($urandom_range(16'h00FA, 0));
                w = $urandom_range(1);
            end
            if ($urandom_range(99) < 3) s = 3'b001;
            id = bfm.push(a, w, 8'($urandom), ($urandom_range(99) < 60) ? 0 : $urandom_range(6, 1), s);
        end
    endtask

    // ---------------- Test ----------------
    int unsigned n_irq_rx = 0, n_irq_tx = 0, n_irq_err = 0, n_irq_fe = 0, n_irq_oe = 0;
    int unsigned n_oe = 0, n_pe = 0, n_fe = 0;
    int unsigned n_resets = 0, n_hsize = 0, n_tx_fill = 0;
    bit stream_done = 1'b0;

    initial begin
        bit r, cov_ok;
        logic [7:0] rd, v;
        int k;
        repeat (3) @(negedge clk);
        rstn = 1'b1;
        wait_cycles(2);

        // 1. Reset state.
        rd_is(ST, 8'h40); rd_is(IE, 8'h00);
        if (irq !== 1'b0 || txd !== 1'b1) fail("IRQ/TXD after reset");

        // 2. Errors without side effects.
        err(RX, 1'b0, 8'h00);                     // RX empty
        err(RX, 1'b1, 8'h11);                     // write to RX_DATA
        err(TX, 1'b0, 8'h00);                     // read TX_DATA
        err(ST, 1'b1, 8'hFF);
        err(EC, 1'b0, 8'h00);
        err(16'hFF05, 1'b0, 8'h00); err(16'hFF05, 1'b1, 8'h01);
        err(16'hF000, 1'b0, 8'h00); err(16'hFFFF, 1'b1, 8'h01);
        acc(ST, 1'b0, 8'h00, r, rd, 3'b001);      // HSIZE error in the bridge
        if (!r) fail("HSIZE=001 got OKAY"); else n_hsize++;
        rd_is(ST, 8'h40);
        wait_cycles(12 * BIT);
        if (tx_seen.size() != 0) fail("TXD sent a byte after error transfers");

        // 3. TX: five bytes, then fill until full (1 in the shifter + DEPTH).
        for (int i = 0; i < 5; i++) ok(TX, 1'b1, 8'($urandom));
        tx_drain();
        if (!same(tx_seen, tx_written)) fail("TX bytes differ (5 bytes)");
        for (k = 0; k < 40; k++) begin
            acc(TX, 1'b1, 8'($urandom), r, rd);
            if (r) break;
        end
        n_tx_fill = k;
        if (k != DEPTH + 1) fail($sformatf("TX accepted %0d bytes before full, expected %0d", k, DEPTH + 1));
        rd_is(ST, 8'h06);                         // TX_FULL, TX_BUSY
        tx_drain();
        if (!same(tx_seen, tx_written)) fail("TX bytes differ (fill)");
        rd_is(ST, 8'h40);

        // 4. RX: three bytes, read back, then empty.
        for (int i = 0; i < 3; i++) send_byte(8'($urandom));
        rd_is(ST, 8'h41);
        for (int i = 0; i < 3; i++) ok(RX, 1'b0, 8'h00);
        err(RX, 1'b0, 8'h00);

        // 5. Overrun: DEPTH + 1 bytes, the last one is lost.
        for (int i = 0; i < DEPTH; i++) send_byte(8'($urandom));
        send_byte(8'hA5, 1'b0, 1'b0, 1'b0);
        rd_is(ST, 8'h49);                         // RX_VALID, OVERRUN, TX_EMPTY
        if (c_oe) n_oe++;
        for (int i = 0; i < DEPTH; i++) ok(RX, 1'b0, 8'h00);
        err(RX, 1'b0, 8'h00);

        // 6. Parity and frame errors; ERROR_CLEAR bit by bit.
        send_byte(8'h3C, 1'b1, 1'b0);             // parity error
        send_byte(8'hC3, 1'b0, 1'b1);             // frame error
        rd_is(ST, 8'h79);                         // PE, FE, OE, TX_EMPTY, RX_VALID
        if (c_pe) n_pe++;
        if (c_fe) n_fe++;
        ok(RX, 1'b0, 8'h00); ok(RX, 1'b0, 8'h00);
        ok(EC, 1'b1, 8'h00); rd_is(ST, 8'h78);    // no change
        ok(EC, 1'b1, 8'hC7); rd_is(ST, 8'h78);    // bits outside [5:3]: no change
        ok(EC, 1'b1, 8'h10); rd_is(ST, 8'h68);    // FE
        ok(EC, 1'b1, 8'h20); rd_is(ST, 8'h48);    // PE
        ok(EC, 1'b1, 8'h08); rd_is(ST, 8'h40);    // OE

        // 7. IRQ_EN read back.
        ok(IE, 1'b1, 8'hFF); rd_is(IE, 8'h07);
        ok(IE, 1'b1, 8'h00); rd_is(IE, 8'h00);

        // 8. IRQ per source.
        ok(IE, 1'b1, 8'h01); irq_is(1'b0, "RX enabled, RX empty");
        send_byte(8'h5A); irq_is(1'b1, "RX byte arrived");
        if (irq) n_irq_rx++;
        ok(RX, 1'b0, 8'h00); irq_is(1'b0, "RX read");
        ok(IE, 1'b1, 8'h02); irq_is(1'b1, "TX empty enabled");
        if (irq) n_irq_tx++;
        ok(TX, 1'b1, 8'h01); ok(TX, 1'b1, 8'h02); ok(TX, 1'b1, 8'h03);
        irq_is(1'b0, "TX FIFO filled");
        tx_drain(); irq_is(1'b1, "TX drained");
        ok(IE, 1'b1, 8'h00); irq_is(1'b0, "TX empty disabled");
        ok(IE, 1'b1, 8'h04); irq_is(1'b0, "error enabled, no error");
        send_byte(8'h77, 1'b1, 1'b0); irq_is(1'b1, "parity error");
        if (irq) n_irq_err++;
        ok(RX, 1'b0, 8'h00); irq_is(1'b1, "RX read, error flag still set");
        ok(EC, 1'b1, 8'h38); irq_is(1'b0, "flags cleared");
        send_byte(8'h81, 1'b0, 1'b1); irq_is(1'b1, "frame error alone");
        if (irq) n_irq_fe++;
        ok(RX, 1'b0, 8'h00); ok(EC, 1'b1, 8'h10); irq_is(1'b0, "frame error cleared");
        for (int i = 0; i < DEPTH; i++) send_byte(8'($urandom));
        send_byte(8'h5A, 1'b0, 1'b0, 1'b0);      // overrun alone
        irq_is(1'b1, "overrun alone");
        if (irq) n_irq_oe++;
        for (int i = 0; i < DEPTH; i++) ok(RX, 1'b0, 8'h00);
        irq_is(1'b1, "RX drained, overrun flag still set");
        ok(EC, 1'b1, 8'h08); irq_is(1'b0, "overrun cleared");
        ok(IE, 1'b1, 8'h00);
        send_byte(8'h66); irq_is(1'b0, "IRQ disabled, RX byte");
        ok(RX, 1'b0, 8'h00);

        // 9. Reset with TX busy, RX data waiting and all IRQs enabled.
        ok(IE, 1'b1, 8'h07);
        for (int i = 0; i < 4; i++) ok(TX, 1'b1, 8'($urandom));
        send_byte(8'h12); send_byte(8'h34);
        if (c_temt || !c_dr) fail("reset scenario: TX not busy or RX empty");
        wait_idle();
        @(negedge clk) rstn = 1'b0;
        n_resets++;
        tx_written = tx_seen;                     // bytes not sent are lost
        rx_expect = rx_read;                      // bytes not read are lost
        wait_cycles(2);
        rstn = 1'b1;
        wait_cycles(2 * 11 * BIT);
        if (irq !== 1'b0 || txd !== 1'b1) fail("IRQ/TXD after reset");
        rd_is(ST, 8'h40); rd_is(IE, 8'h00);

        // 10. Random register traffic while bytes arrive on RXD.
        check_clr = 1'b0;
        fork
            begin
                for (int i = 0; i < 120; i++) begin
                    int unsigned p;
                    p = $urandom_range(99);
                    send_byte(8'($urandom), p < 5, (p >= 5 && p < 8));
                    repeat ($urandom_range(300, 0)) @(posedge clk);
                end
                stream_done = 1'b1;
            end
            begin
                while (!stream_done) begin random_ops(20); wait_idle(); end
            end
        join
        // Drain RX and TX.
        do acc(RX, 1'b0, 8'h00, r, rd); while (!r);
        tx_drain();

        // 11. Back-to-back frames (no idle bit) from a sender with a nominal,
        //     2% fast and 2% slow clock: DEPTH bytes each, no error flag, all
        //     bytes read back in order (final check against rx_expect).
        ok(EC, 1'b1, 8'h38);
        for (int s = 0; s < 3; s++) begin
            real bt;
            bt = (s == 0) ? 320.0 : (s == 1) ? 320.0 / 1.02 : 320.0 / 0.98;
            send_burst(DEPTH, bt);
            wait_cycles(BIT);
            v = {1'b0, c_thre, c_pe, c_fe, c_oe, !c_temt, c_full, c_dr};
            if (v !== 8'h41)
                fail($sformatf("back-to-back burst %0d: STATUS %h, expected 41 (bit %0.1f ns)", s, v, bt));
            for (int i = 0; i < DEPTH; i++) ok(RX, 1'b0, 8'h00);
            err(RX, 1'b0, 8'h00);
        end

        // Final checks.
        if (!same(tx_seen, tx_written))
            fail($sformatf("TXD bytes (%0d) differ from TX_DATA writes (%0d)", tx_seen.size(), tx_written.size()));
        if (!same(rx_read, rx_expect))
            fail($sformatf("RX_DATA reads (%0d) differ from bytes sent (%0d)", rx_read.size(), rx_expect.size()));
        begin
            int unsigned q;
            q = 0;
            for (int i = 0; i < bfm.results.size(); i++) begin
                bit rr, ww;
                logic [7:0] dd;
                logic [2:0] ss;
                rr = bfm.results[i].resp; ww = bfm.results[i].write;
                dd = bfm.results[i].rdata; ss = bfm.results[i].size;
                if (ss != 3'b000) begin
                    if (!rr) fail("HSIZE error transfer got OKAY");
                end else if (q >= apb_seq.size()) begin
                    fail("AHB transfer without an APB transfer");
                end else begin
                    if (rr != apb_seq[q].err || (!rr && !ww && dd !== apb_seq[q].rdata))
                        fail($sformatf("AHB result %0d differs from APB transfer %0d", i, q));
                    q++;
                end
            end
            if (q != apb_seq.size()) fail($sformatf("%0d APB transfers, %0d AHB results", apb_seq.size(), q));
        end
        fails += chk_apb.fails + chk_ahb.fails;

        cov_ok = n_rx_ok && n_rx_empty && n_rx_wr && n_tx_ok && n_tx_full && n_tx_rd && n_st &&
                 n_st_wr && n_ec && n_ec_rd && n_ie_wr && n_ie_rd && n_unmapped && n_hsize &&
                 n_irq_rx && n_irq_tx && n_irq_err && n_irq_fe && n_irq_oe &&
                 n_oe && n_pe && n_fe && n_resets &&
                 n_tx_fill == DEPTH + 1 && n_b2b == 3 * DEPTH;
        $display("COVER rx ok=%0d empty=%0d write=%0d | tx ok=%0d full=%0d read=%0d | status=%0d st_write=%0d | clear=%0d clear_read=%0d | irq_en w=%0d r=%0d | unmapped=%0d hsize=%0d",
                 n_rx_ok, n_rx_empty, n_rx_wr, n_tx_ok, n_tx_full, n_tx_rd, n_st, n_st_wr,
                 n_ec, n_ec_rd, n_ie_wr, n_ie_rd, n_unmapped, n_hsize);
        $display("COVER irq rx/tx/parity/frame/overrun=%0d/%0d/%0d/%0d/%0d flags oe/pe/fe=%0d/%0d/%0d resets=%0d tx_frames=%0d rx_bytes=%0d b2b=%0d",
                 n_irq_rx, n_irq_tx, n_irq_err, n_irq_fe, n_irq_oe, n_oe, n_pe, n_fe, n_resets,
                 n_tx_frames, rx_read.size(), n_b2b);
        if (!cov_ok) fail("coverage count below 1 (see COVER lines)");

        if (fails == 0)
            $display("UART_APB_PASS apb_transfers=%0d tx_bytes=%0d rx_bytes=%0d irq_sources=3 resets=%0d",
                     apb_seq.size(), tx_seen.size(), rx_read.size(), n_resets);
        else
            $display("UART_APB_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #50ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
