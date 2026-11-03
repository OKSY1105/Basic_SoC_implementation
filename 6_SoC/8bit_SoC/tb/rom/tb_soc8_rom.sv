`timescale 1ns/1ps
// Unit TB for soc8_rom (M5).
// Port A: ahb_lite_master_bfm (17-bit address, 16-bit data), point-to-point
//   like the CPU instruction port (HREADY = ROM HREADYOUT).
// Port B: ahb_lite_master_bfm -> soc8_ahb_bus -> ROM port B, with slave
//   models in the RAM and APB regions, so other slaves stretch HREADY while
//   a ROM address phase waits.
// Reference: the TB keeps its own copy of the contents (loaded from the same
//   image file, later filled through the hierarchy) and checks every
//   completed transfer of both ports: response, read data and byte lane,
//   zero wait for OKAY and one low cycle for ERROR.
// Phases:
//   1. Image: every word on port A and every byte on port B against
//      rom_test.mem (zero outside the image).
//   2. Random contents, both ports at once, including bad transfers (write,
//      wrong HSIZE, odd or out-of-range instruction address) and a hot area
//      so that both ports read the same word in the same cycle.
//   3. Resets during traffic and during a port A ERROR, then every word
//      again (contents survive reset).
// The run directory must contain rom_test.mem (copy it from this folder).
// Prints ROM_PASS only if no check failed and every coverage count is >= 1.
module tb_soc8_rom;
    localparam integer R_DEF = 0, R_ROM = 1, R_RAM = 2, R_APB = 3;
    localparam MEM_FILE = "rom_test.mem";

    reg clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;

    // Port A (instruction)
    wire [16:0] a_haddr;
    wire [1:0]  a_htrans;
    wire        a_hwrite;
    wire [2:0]  a_hsize;
    wire [15:0] a_hwdata, a_hrdata;
    wire        a_hready, a_hresp;
    // Port B side (data bus)
    wire [15:0] b_haddr;
    wire [1:0]  b_htrans;
    wire        b_hwrite;
    wire [2:0]  b_hsize;
    wire [7:0]  b_hwdata, b_hrdata;
    wire        b_hready, b_hresp;
    wire        sel_rom, sel_ram, sel_apb;
    wire [7:0]  rd_rom, rd_ram, rd_apb;
    wire        ro_rom, ro_ram, ro_apb, rs_rom, rs_ram, rs_apb;
    wire [15:0] err_addr, err_count;

    ahb_lite_master_bfm #(.ADDR_W(17), .DATA_W(16)) bfm_a (
        .clk(clk), .rstn(rstn), .haddr(a_haddr), .htrans(a_htrans), .hwrite(a_hwrite),
        .hsize(a_hsize), .hwdata(a_hwdata), .hrdata(a_hrdata), .hready(a_hready), .hresp(a_hresp));
    ahb_lite_master_bfm bfm_b (
        .clk(clk), .rstn(rstn), .haddr(b_haddr), .htrans(b_htrans), .hwrite(b_hwrite),
        .hsize(b_hsize), .hwdata(b_hwdata), .hrdata(b_hrdata), .hready(b_hready), .hresp(b_hresp));

    soc8_ahb_bus bus (
        .i_clk(clk), .i_rstn(rstn), .i_haddr(b_haddr), .i_htrans(b_htrans),
        .o_hrdata(b_hrdata), .o_hready(b_hready), .o_hresp(b_hresp),
        .o_hsel_rom(sel_rom), .o_hsel_ram(sel_ram), .o_hsel_apb(sel_apb),
        .i_hrdata_rom(rd_rom), .i_hreadyout_rom(ro_rom), .i_hresp_rom(rs_rom),
        .i_hrdata_ram(rd_ram), .i_hreadyout_ram(ro_ram), .i_hresp_ram(rs_ram),
        .i_hrdata_apb(rd_apb), .i_hreadyout_apb(ro_apb), .i_hresp_apb(rs_apb),
        .o_err_addr(err_addr), .o_err_count(err_count));

    soc8_rom #(.MEM_FILE(MEM_FILE)) dut (
        .i_clk(clk), .i_rstn(rstn),
        .i_a_hsel(1'b1), .i_a_haddr(a_haddr), .i_a_htrans(a_htrans), .i_a_hwrite(a_hwrite),
        .i_a_hsize(a_hsize), .i_a_hready(a_hready),
        .o_a_hreadyout(a_hready), .o_a_hresp(a_hresp), .o_a_hrdata(a_hrdata),
        .i_b_hsel(sel_rom), .i_b_haddr(b_haddr), .i_b_htrans(b_htrans), .i_b_hwrite(b_hwrite),
        .i_b_hsize(b_hsize), .i_b_hready(b_hready),
        .o_b_hreadyout(ro_rom), .o_b_hresp(rs_rom), .o_b_hrdata(rd_rom));

    ahb_lite_slave_model #(.ID(R_RAM), .MIN_WAIT(0), .MAX_WAIT(6)) ram (
        .clk(clk), .rstn(rstn), .hsel(sel_ram), .haddr(b_haddr), .htrans(b_htrans),
        .hwrite(b_hwrite), .hwdata(b_hwdata), .hready(b_hready),
        .hreadyout(ro_ram), .hresp(rs_ram), .hrdata(rd_ram));
    ahb_lite_slave_model #(.ID(R_APB), .MIN_WAIT(1), .MAX_WAIT(4)) apb (
        .clk(clk), .rstn(rstn), .hsel(sel_apb), .haddr(b_haddr), .htrans(b_htrans),
        .hwrite(b_hwrite), .hwdata(b_hwdata), .hready(b_hready),
        .hreadyout(ro_apb), .hresp(rs_apb), .hrdata(rd_apb));

    // Response rules of both ROM ports; MAX_WAIT 0 = OKAY never waits.
    ahb_lite_slave_checker #(.MAX_WAIT(0)) chk_a (
        .clk(clk), .rstn(rstn), .hsel(1'b1), .htrans(a_htrans),
        .hready(a_hready), .hreadyout(a_hready), .hresp(a_hresp));
    ahb_lite_slave_checker #(.MAX_WAIT(0)) chk_b (
        .clk(clk), .rstn(rstn), .hsel(sel_rom), .htrans(b_htrans),
        .hready(b_hready), .hreadyout(ro_rom), .hresp(rs_rom));

    // ---------------- Reference model ----------------
    logic [15:0] ref_mem [0:4095];
    int unsigned image_words = 0;
    initial begin
        for (int i = 0; i < 4096; i++) ref_mem[i] = 16'h0000;
        $readmemh(MEM_FILE, ref_mem);
        for (int i = 0; i < 4096; i++) if (ref_mem[i] != 16'h0000) image_words++;
    end

    function automatic int region_of(input logic [15:0] a);
        if (a <= 16'h1FFF) return R_ROM;
        if (a >= 16'h8000 && a <= 16'h87FF) return R_RAM;
        if (a >= 16'hF000) return R_APB;
        return R_DEF;
    endfunction
    // Read-data pattern of ahb_lite_slave_model with ID = region.
    function automatic logic [7:0] data_of(input int id, input logic [15:0] a);
        return 8'((a ^ (a >> 8)) + id * 8'h35);
    endfunction
    function automatic bit a_bad(input logic [16:0] a, input bit w, input bit [2:0] s);
        return w || s != 3'b001 || a[0] || a[16:13] != 4'd0;
    endfunction
    function automatic logic [7:0] rom_byte(input logic [15:0] a);
        return a[0] ? ref_mem[a[12:1]][15:8] : ref_mem[a[12:1]][7:0];
    endfunction

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // ---------------- Result checks ----------------
    int unsigned n_a_ok = 0, n_a_write = 0, n_a_size = 0, n_a_odd = 0, n_a_range = 0;
    int unsigned n_b_lo = 0, n_b_hi = 0, n_b_write = 0, n_b_size = 0, n_b_other = 0;
    bit cov_a_first = 0, cov_a_last = 0, cov_b_first = 0, cov_b_last = 0;

    task automatic check_a();
        for (int i = 0; i < bfm_a.results.size(); i++) begin
            logic [16:0] a;
            bit bad;
            a = bfm_a.results[i].addr;
            bad = a_bad(a, bfm_a.results[i].write, bfm_a.results[i].size);
            if (bfm_a.results[i].resp != bad)
                fail($sformatf("port A HADDR=%h W=%0d HSIZE=%0d response %0d, expected %0d", a,
                     bfm_a.results[i].write, bfm_a.results[i].size, bfm_a.results[i].resp, bad));
            else if (!bad && bfm_a.results[i].rdata != ref_mem[a[12:1]])
                fail($sformatf("port A HADDR=%h read %h, expected %h", a,
                     bfm_a.results[i].rdata, ref_mem[a[12:1]]));
            if (bfm_a.results[i].wait_cycles != (bad ? 1 : 0))
                fail($sformatf("port A HADDR=%h wait %0d", a, bfm_a.results[i].wait_cycles));
            if (!bad) begin
                n_a_ok++;
                if (a == 17'h00000) cov_a_first = 1;
                if (a == 17'h01FFE) cov_a_last = 1;
            end
            if (bfm_a.results[i].write) n_a_write++;
            if (bfm_a.results[i].size != 3'b001) n_a_size++;
            if (a[0]) n_a_odd++;
            if (a[16:13] != 4'd0) n_a_range++;
        end
        bfm_a.results.delete();
    endtask

    task automatic check_b();
        for (int i = 0; i < bfm_b.results.size(); i++) begin
            logic [15:0] a;
            logic [7:0] d;
            bit bad;
            int r;
            a = bfm_b.results[i].addr;
            r = region_of(a);
            if (r == R_ROM) begin
                bad = bfm_b.results[i].write || bfm_b.results[i].size != 3'b000;
                d = rom_byte(a);
                if (bfm_b.results[i].wait_cycles != (bad ? 1 : 0))
                    fail($sformatf("port B HADDR=%h wait %0d", a, bfm_b.results[i].wait_cycles));
                if (!bad) begin
                    if (a[0]) n_b_hi++; else n_b_lo++;
                    if (a == 16'h0000) cov_b_first = 1;
                    if (a == 16'h1FFF) cov_b_last = 1;
                end
                if (bfm_b.results[i].write) n_b_write++;
                if (bfm_b.results[i].size != 3'b000) n_b_size++;
            end else begin
                bad = (r == R_DEF) || (a[3:0] == 4'hF);
                d = data_of(r, a);
                n_b_other++;
            end
            if (bfm_b.results[i].resp != bad)
                fail($sformatf("port B HADDR=%h W=%0d HSIZE=%0d response %0d, expected %0d", a,
                     bfm_b.results[i].write, bfm_b.results[i].size, bfm_b.results[i].resp, bad));
            else if (!bad && !bfm_b.results[i].write && bfm_b.results[i].rdata != d)
                fail($sformatf("port B HADDR=%h read %h, expected %h", a, bfm_b.results[i].rdata, d));
        end
        bfm_b.results.delete();
    endtask

    // ---------------- Cycle monitors (coverage) ----------------
    int unsigned n_same_word = 0, n_rom_hold = 0, n_resets = 0;
    bit tb_b_dp = 1'b0;
    int tb_b_dp_region = R_DEF;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tb_b_dp = 1'b0;
        end else begin
            if (a_htrans[1] && a_hready && !a_bad(a_haddr, a_hwrite, a_hsize) &&
                sel_rom && b_htrans[1] && b_hready && !b_hwrite && b_hsize == 3'b000 &&
                a_haddr[12:1] == b_haddr[12:1])
                n_same_word++;                // both ports read one word in one cycle
            if (b_hready) begin
                tb_b_dp = b_htrans[1]; tb_b_dp_region = region_of(b_haddr);
            end else if (b_htrans[1] && sel_rom && tb_b_dp && tb_b_dp_region != R_ROM) begin
                n_rom_hold++;                 // ROM address phase held by another slave
            end
        end
    end
    always @(negedge rstn) n_resets++;

    // ---------------- Stimulus ----------------
    task automatic wait_idle();
        int unsigned t = 0;
        do begin @(negedge clk); t++; end
        while (!(bfm_a.idle() && bfm_b.idle()) && t < 400000);
        if (!(bfm_a.idle() && bfm_b.idle())) fail("BFM did not finish (hang)");
        repeat (2) @(negedge clk);
    endtask

    task automatic push_a_random(input int n);
        repeat (n) begin
            int unsigned p, id;
            logic [16:0] a;
            bit w;
            bit [2:0] s;
            w = 1'b0; s = 3'b001;
            p = $urandom_range(99);
            if (p < 25) a = 17'(2 * $urandom_range(15, 0));         // hot area
            else        a = 17'(2 * $urandom_range(4095, 0));
            p = $urandom_range(99);
            if (p < 3)      a = 17'(2 * ($urandom_range(16'hEFFF, 0) + 16'h1000)); // 0x02000-0x1FFFE
            else if (p < 5) a[0] = 1'b1;
            else if (p < 7) s = $urandom_range(1) ? 3'b000 : 3'b010;
            else if (p < 8) w = 1'b1;
            id = bfm_a.push(a, w, 16'($urandom), ($urandom_range(99) < 70) ? 0 : $urandom_range(2, 1), s);
        end
    endtask

    task automatic push_b_random(input int n);
        repeat (n) begin
            int unsigned p, id;
            logic [15:0] a;
            bit w;
            bit [2:0] s;
            w = 1'b0; s = 3'b000;
            p = $urandom_range(99);
            if (p < 70) begin
                if ($urandom_range(99) < 25) a = 16'($urandom_range(31, 0));   // hot area
                else                         a = 16'($urandom_range(16'h1FFF, 0));
                p = $urandom_range(99);
                if (p < 4)      w = 1'b1;
                else if (p < 7) s = 3'b001;
            end else if (p < 95) begin
                a = 16'h8000 + 16'($urandom_range(16'h07FF, 0));
                w = $urandom_range(99) < 40;
            end else begin
                a = 16'hF000 + 16'($urandom_range(16'h0FFF, 0));
                w = $urandom_range(99) < 40;
            end
            id = bfm_b.push(a, w, 8'($urandom), ($urandom_range(99) < 70) ? 0 : $urandom_range(2, 1), s);
        end
    endtask

    task automatic push_all_words();
        int unsigned id;
        for (int w = 0; w < 4096; w++) id = bfm_a.push(17'(2 * w), 1'b0, 16'h0000, 0, 3'b001);
    endtask

    initial begin
        int unsigned id;
        bit cov_ok;
        repeat (3) @(negedge clk);
        rstn = 1'b1;
        @(negedge clk);
        if (image_words != 48) fail($sformatf("test image: %0d non-zero words, expected 48", image_words));

        // 1. Image: every word on port A, every byte on port B.
        push_all_words();
        for (int b = 0; b < 8192; b++) id = bfm_b.push(16'(b), 1'b0, 8'h00, 0, 3'b000);
        wait_idle(); check_a(); check_b();

        // 2. Random contents (written through the hierarchy), both ports at once.
        for (int i = 0; i < 4096; i++) begin
            logic [15:0] v;
            v = 16'($urandom);
            dut.r_mem[i] = v; ref_mem[i] = v;
        end
        bfm_b.cancel_on_error = 1'b0;
        push_a_random(6000); push_b_random(6000); wait_idle();
        bfm_b.cancel_on_error = 1'b1;
        push_a_random(6000); push_b_random(6000); wait_idle();
        check_a(); check_b();

        // 3. Resets during traffic, reset during a port A ERROR.
        repeat (15) begin
            push_a_random(50); push_b_random(50);
            repeat ($urandom_range(60, 5)) @(negedge clk);
            rstn = 1'b0; @(negedge clk); rstn = 1'b1;
            @(negedge clk);
            if (!a_hready || a_hresp || !b_hready || b_hresp) fail("not ready/OKAY after reset");
        end
        wait_idle();
        id = bfm_a.push(17'h02000, 1'b0, 16'h0000, 0, 3'b001);
        do @(negedge clk); while (!(a_hresp && !a_hready));
        rstn = 1'b0; @(negedge clk); rstn = 1'b1;
        @(negedge clk);
        if (!a_hready || a_hresp) fail("port A ERROR state survived reset");
        push_all_words();
        wait_idle(); check_a(); check_b();

        fails += chk_a.fails + chk_b.fails + ram.fails + apb.fails;
        cov_ok = n_a_ok > 1000 && n_a_write && n_a_size && n_a_odd && n_a_range &&
                 n_b_lo > 1000 && n_b_hi > 1000 && n_b_write && n_b_size && n_b_other &&
                 cov_a_first && cov_a_last && cov_b_first && cov_b_last &&
                 n_same_word && n_rom_hold && n_resets >= 16;
        $display("COVER portA ok=%0d write=%0d size=%0d odd=%0d range=%0d | portB lo=%0d hi=%0d write=%0d size=%0d other=%0d",
                 n_a_ok, n_a_write, n_a_size, n_a_odd, n_a_range,
                 n_b_lo, n_b_hi, n_b_write, n_b_size, n_b_other);
        $display("COVER same_word=%0d rom_hold=%0d resets=%0d first/last A=%0d%0d B=%0d%0d image_words=%0d",
                 n_same_word, n_rom_hold, n_resets, cov_a_first, cov_a_last,
                 cov_b_first, cov_b_last, image_words);
        if (!cov_ok) fail("coverage count below 1 (see COVER lines)");

        if (fails == 0)
            $display("ROM_PASS portA_ok=%0d portB_ok=%0d same_word=%0d rom_hold=%0d resets=%0d",
                     n_a_ok, n_b_lo + n_b_hi, n_same_word, n_rom_hold, n_resets);
        else
            $display("ROM_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #20ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
