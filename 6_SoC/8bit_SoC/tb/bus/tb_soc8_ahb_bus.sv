`timescale 1ns/1ps
// Unit TB for soc8_ahb_bus (AHB decoder + response multiplexer + default
// slave).
// Master: ahb_lite_master_bfm. Slaves: three ahb_lite_slave_model instances
// (ROM-like zero wait, RAM-like 0..6 waits, APB-like 1..4 waits), each with
// ERROR on HADDR[3:0]==F and random outputs while it does not own the data
// phase.
// Checks (reference model written here, independent of the DUT):
//   - HSEL of every cycle against the address map.
//   - Every completed transfer: response (ERROR for unmapped addresses and
//     for the slave's error pattern) and read data of the right slave.
//   - Each slave saw exactly the completed transfers routed to it, in order,
//     with the right write data: none lost, duplicated or misrouted.
//   - Default-slave debug outputs (last unmapped address, count).
//   - Bus response rules seen by the master (ahb_lite_slave_checker, SVA)
//     and the slave-side "data phase ended while waiting" check.
// Scenarios: boundary addresses, random traffic without and with cancel
// after ERROR, resets during traffic, reset during a default-slave ERROR.
// Prints AHB_BUS_PASS only if no check failed and every coverage count is
// at least 1.
module tb_soc8_ahb_bus;
    localparam integer R_DEF = 0, R_ROM = 1, R_RAM = 2, R_APB = 3;

    reg clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;

    wire [15:0] haddr;
    wire [1:0]  htrans;
    wire        hwrite;
    wire [2:0]  hsize;
    wire [7:0]  hwdata, hrdata;
    wire        hready, hresp;
    wire        sel_rom, sel_ram, sel_apb;
    wire [7:0]  rd_rom, rd_ram, rd_apb;
    wire        ro_rom, ro_ram, ro_apb, rs_rom, rs_ram, rs_apb;
    wire [15:0] err_addr, err_count;

    ahb_lite_master_bfm bfm (
        .clk(clk), .rstn(rstn), .haddr(haddr), .htrans(htrans), .hwrite(hwrite),
        .hsize(hsize), .hwdata(hwdata), .hrdata(hrdata), .hready(hready), .hresp(hresp));

    soc8_ahb_bus dut (
        .i_clk(clk), .i_rstn(rstn), .i_haddr(haddr), .i_htrans(htrans),
        .o_hrdata(hrdata), .o_hready(hready), .o_hresp(hresp),
        .o_hsel_rom(sel_rom), .o_hsel_ram(sel_ram), .o_hsel_apb(sel_apb),
        .i_hrdata_rom(rd_rom), .i_hreadyout_rom(ro_rom), .i_hresp_rom(rs_rom),
        .i_hrdata_ram(rd_ram), .i_hreadyout_ram(ro_ram), .i_hresp_ram(rs_ram),
        .i_hrdata_apb(rd_apb), .i_hreadyout_apb(ro_apb), .i_hresp_apb(rs_apb),
        .o_err_addr(err_addr), .o_err_count(err_count));

    ahb_lite_slave_model #(.ID(R_ROM), .MIN_WAIT(0), .MAX_WAIT(0)) rom (
        .clk(clk), .rstn(rstn), .hsel(sel_rom), .haddr(haddr), .htrans(htrans),
        .hwrite(hwrite), .hwdata(hwdata), .hready(hready),
        .hreadyout(ro_rom), .hresp(rs_rom), .hrdata(rd_rom));
    ahb_lite_slave_model #(.ID(R_RAM), .MIN_WAIT(0), .MAX_WAIT(6)) ram (
        .clk(clk), .rstn(rstn), .hsel(sel_ram), .haddr(haddr), .htrans(htrans),
        .hwrite(hwrite), .hwdata(hwdata), .hready(hready),
        .hreadyout(ro_ram), .hresp(rs_ram), .hrdata(rd_ram));
    ahb_lite_slave_model #(.ID(R_APB), .MIN_WAIT(1), .MAX_WAIT(4)) apb (
        .clk(clk), .rstn(rstn), .hsel(sel_apb), .haddr(haddr), .htrans(htrans),
        .hwrite(hwrite), .hwdata(hwdata), .hready(hready),
        .hreadyout(ro_apb), .hresp(rs_apb), .hrdata(rd_apb));

    // The whole interconnect seen from the master is one AHB-Lite slave.
    ahb_lite_slave_checker #(.MAX_WAIT(8)) chk (
        .clk(clk), .rstn(rstn), .hsel(1'b1), .htrans(htrans),
        .hready(hready), .hreadyout(hready), .hresp(hresp));

    // ---------------- Reference model ----------------
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

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // ---------------- Cycle monitors ----------------
    // HSEL against the address map (every cycle, also IDLE and reset).
    always @(negedge clk) begin
        int r;
        r = region_of(haddr);
        if ({sel_rom, sel_ram, sel_apb} != {r == R_ROM, r == R_RAM, r == R_APB})
            fail($sformatf("HSEL rom/ram/apb=%b%b%b for HADDR=%h", sel_rom, sel_ram, sel_apb, haddr));
    end

    // Default-slave debug outputs, and coverage of the bus phases.
    logic [15:0] exp_err_addr = 16'd0;
    int unsigned exp_err_count = 0;
    bit tb_dp = 1'b0;                     // NONSEQ in data phase
    int tb_dp_region = R_DEF;
    int unsigned pair [0:3][0:3];         // data-phase region -> next region
    int unsigned n_cross_hold = 0, n_idle_def = 0, n_resets = 0;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            exp_err_addr = 16'd0; exp_err_count = 0; tb_dp = 1'b0;
        end else if (hready) begin
            if (htrans[1] && region_of(haddr) == R_DEF) begin
                exp_err_addr = haddr; exp_err_count++;
            end
            if (!htrans[1] && region_of(haddr) == R_DEF) n_idle_def++;
            if (tb_dp && htrans[1]) pair[tb_dp_region][region_of(haddr)]++;
            tb_dp = htrans[1]; tb_dp_region = region_of(haddr);
        end else if (htrans[1] && tb_dp && region_of(haddr) != tb_dp_region) begin
            n_cross_hold++;               // next slave's address held while another waits
        end
    end
    always @(negedge clk) if (rstn) begin
        if (err_addr != exp_err_addr || err_count != 16'(exp_err_count))
            fail($sformatf("default slave debug addr=%h count=%0d, expected %h %0d",
                           err_addr, err_count, exp_err_addr, exp_err_count));
    end
    always @(negedge rstn) n_resets++;

    // ---------------- Stimulus ----------------
    task automatic wait_idle();
        int unsigned t = 0;
        do begin @(negedge clk); t++; end while (!bfm.idle() && t < 200000);
        if (!bfm.idle()) fail("BFM did not finish (bus hang)");
        repeat (2) @(negedge clk);
    endtask

    function automatic logic [15:0] random_addr();
        int unsigned p = $urandom_range(99);
        if (p < 28) return 16'($urandom_range(16'h1FFF, 0));
        if (p < 56) return 16'h8000 + 16'($urandom_range(16'h07FF, 0));
        if (p < 80) return 16'hF000 + 16'($urandom_range(16'h0FFF, 0));
        if (p < 90) return 16'h2000 + 16'($urandom_range(16'h5FFF, 0));   // 2000-7FFF
        return 16'h8800 + 16'($urandom_range(16'h67FF, 0));               // 8800-EFFF
    endfunction

    task automatic random_ops(input int n);
        repeat (n) begin
            int unsigned id;
            id = bfm.push(random_addr(), $urandom_range(99) < 40, 8'($urandom),
                          ($urandom_range(99) < 70) ? 0 : $urandom_range(3, 1));
        end
    endtask

    localparam integer NB = 10;
    logic [15:0] boundary [0:NB-1] = '{16'h0000, 16'h1FFF, 16'h2000, 16'h7FFF, 16'h8000,
                                       16'h87FF, 16'h8800, 16'hEFFF, 16'hF000, 16'hFFFF};

    // ---------------- Result checks ----------------
    typedef struct {
        logic [15:0] addr;
        bit          write;
        logic [7:0]  data;
        bit          resp;
    } exp_t;
    exp_t exp_q [0:3][$];
    int unsigned n_ops [0:3], n_okay [0:3], n_err [0:3], n_boundary = 0;
    int unsigned max_wait = 0;

    task automatic check_results();
        for (int i = 0; i < bfm.results.size(); i++) begin
            int r;
            bit exp_err;
            exp_t e;
            r = region_of(bfm.results[i].addr);
            exp_err = (r == R_DEF) || (bfm.results[i].addr[3:0] == 4'hF);
            n_ops[r]++;
            if (exp_err) n_err[r]++; else n_okay[r]++;
            if (bfm.results[i].wait_cycles > max_wait) max_wait = bfm.results[i].wait_cycles;
            for (int b = 0; b < NB; b++) if (bfm.results[i].addr == boundary[b]) n_boundary++;
            if (bfm.results[i].resp != exp_err)
                fail($sformatf("op %0d HADDR=%h response %0d, expected %0d", bfm.results[i].id,
                               bfm.results[i].addr, bfm.results[i].resp, exp_err));
            else if (!exp_err && !bfm.results[i].write &&
                     bfm.results[i].rdata != data_of(r, bfm.results[i].addr))
                fail($sformatf("op %0d HADDR=%h read %h, expected %h", bfm.results[i].id,
                               bfm.results[i].addr, bfm.results[i].rdata,
                               data_of(r, bfm.results[i].addr)));
            if (r != R_DEF) begin
                e.addr = bfm.results[i].addr; e.write = bfm.results[i].write;
                e.data = bfm.results[i].write ? bfm.results[i].wdata
                                              : data_of(r, bfm.results[i].addr);
                e.resp = exp_err;
                exp_q[r].push_back(e);
            end
        end
    endtask

    `define CHECK_LOG(INST, R, NAME) \
        if (INST.log.size() != exp_q[R].size()) \
            fail($sformatf("%s saw %0d transfers, expected %0d", NAME, INST.log.size(), exp_q[R].size())); \
        else for (int k = 0; k < exp_q[R].size(); k++) \
            if (INST.log[k].addr != exp_q[R][k].addr || INST.log[k].write != exp_q[R][k].write || \
                (!exp_q[R][k].resp && INST.log[k].data != exp_q[R][k].data) || \
                INST.log[k].resp != exp_q[R][k].resp) \
                fail($sformatf("%s transfer %0d: HADDR=%h W=%0d data=%h resp=%0d, expected %h %0d %h %0d", \
                     NAME, k, INST.log[k].addr, INST.log[k].write, INST.log[k].data, INST.log[k].resp, \
                     exp_q[R][k].addr, exp_q[R][k].write, exp_q[R][k].data, exp_q[R][k].resp));

    initial begin
        int unsigned id;
        bit cov_ok;
        repeat (3) @(negedge clk);
        rstn = 1'b1;
        @(negedge clk);
        if (!hready || hresp) fail("bus not ready/OKAY after reset");

        // 1. Boundary addresses, read then write, back to back.
        for (int b = 0; b < NB; b++) begin
            id = bfm.push(boundary[b], 1'b0, 8'h00);
            id = bfm.push(boundary[b], 1'b1, 8'($urandom));
        end
        wait_idle();

        // 2. Random traffic: the master continues after ERROR, then cancels.
        bfm.cancel_on_error = 1'b0; random_ops(8000); wait_idle();
        bfm.cancel_on_error = 1'b1; random_ops(8000); wait_idle();

        // 3. Resets in the middle of traffic.
        repeat (20) begin
            random_ops(60);
            repeat ($urandom_range(80, 3)) @(negedge clk);
            rstn = 1'b0; @(negedge clk); rstn = 1'b1;
            @(negedge clk);
            if (!hready || hresp) fail("bus not ready/OKAY after reset");
        end
        wait_idle();

        // 4. Reset in the first cycle of a default-slave ERROR.
        id = bfm.push(16'h4000, 1'b0, 8'h00);
        do @(negedge clk); while (!(hresp && !hready));
        rstn = 1'b0; @(negedge clk); rstn = 1'b1;
        @(negedge clk);
        if (!hready || hresp || err_count != 16'd0) fail("ERROR state survived reset");
        id = bfm.push(16'h8001, 1'b0, 8'h00);
        wait_idle();

        // Final checks.
        check_results();
        `CHECK_LOG(rom, R_ROM, "rom")
        `CHECK_LOG(ram, R_RAM, "ram")
        `CHECK_LOG(apb, R_APB, "apb")
        fails += chk.fails + rom.fails + ram.fails + apb.fails;

        cov_ok = 1'b1;
        for (int r = 0; r < 4; r++) begin
            if (n_ops[r] < 100 || n_err[r] == 0 || (r != R_DEF && n_okay[r] == 0)) cov_ok = 1'b0;
            for (int s = 0; s < 4; s++) if (pair[r][s] == 0) cov_ok = 1'b0;
        end
        if (n_cross_hold == 0 || n_idle_def == 0 || bfm.n_cancel == 0 || n_resets < 21 ||
            n_boundary < 2 * NB || ram.n_wait_cycles == 0 || apb.n_wait_cycles == 0 ||
            rom.n_junk_low == 0 || ram.n_junk_low == 0 || apb.n_junk_low == 0)
            cov_ok = 1'b0;

        $display("COVER ops rom=%0d ram=%0d apb=%0d unmapped=%0d | errors rom=%0d ram=%0d apb=%0d",
                 n_ops[R_ROM], n_ops[R_RAM], n_ops[R_APB], n_ops[R_DEF],
                 n_err[R_ROM], n_err[R_RAM], n_err[R_APB]);
        $display("COVER cancels=%0d resets=%0d cross_hold=%0d idle_unmapped=%0d boundary=%0d max_wait=%0d junk_low=%0d/%0d/%0d",
                 bfm.n_cancel, n_resets, n_cross_hold, n_idle_def, n_boundary, max_wait,
                 rom.n_junk_low, ram.n_junk_low, apb.n_junk_low);
        for (int r = 0; r < 4; r++)
            $display("COVER pair from %0d: %0d %0d %0d %0d", r, pair[r][0], pair[r][1], pair[r][2], pair[r][3]);
        if (!cov_ok) fail("coverage count below 1 (see COVER lines)");

        if (fails == 0)
            $display("AHB_BUS_PASS transfers=%0d unmapped=%0d cancels=%0d resets=%0d max_wait=%0d",
                     bfm.results.size(), n_ops[R_DEF], bfm.n_cancel, n_resets, max_wait);
        else
            $display("AHB_BUS_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #20ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
