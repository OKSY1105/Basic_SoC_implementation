`timescale 1ns/1ps
// Unit TB for ahb_apb_bridge.
// AHB side: ahb_lite_master_bfm, a TB-local decoder/multiplexer, the bridge
//   at 0xF000-0xFFFF and an ahb_lite_slave_model (0..4 waits) everywhere
//   else, so the other slave stretches HREADY while a bridge address phase
//   waits. APB side: apb_slave_model (0..5 PREADY waits, PSLVERR on
//   PADDR[3:0]==F, random PREADY/PSLVERR/PRDATA outside ACCESS).
// Checks (reference written here, independent of the DUT):
//   - Every completed AHB transfer to the bridge: response (ERROR for
//     HSIZE != 000 or PSLVERR), read data, and exact wait cycles
//     (OKAY: 2 + APB waits, PSLVERR: 3 + APB waits, HSIZE error: 1).
//   - The APB transfers equal the good-size bridge transfers one to one, in
//     order: PADDR = HADDR[11:0], PWRITE, PWDATA = HWDATA. No APB transfer
//     for HSIZE errors, IDLE or other slaves.
//   - The other slave's transfers and responses (no misrouting).
//   - APB protocol (apb_checker) and AHB response rules of the bridge
//     (ahb_lite_slave_checker), both SVA.
// Scenarios: directed, random traffic without and with cancel after ERROR,
// resets during APB SETUP and ACCESS.
// Prints APB_BRIDGE_PASS only if no check failed and every coverage count
// is at least 1.
module tb_ahb_apb_bridge;
    localparam integer APB_MAX_WAIT = 5;
    localparam integer ID_OTHER = 1, ID_APB = 3;

    reg clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;

    wire [15:0] haddr;
    wire [1:0]  htrans;
    wire        hwrite;
    wire [2:0]  hsize;
    wire [7:0]  hwdata, hrdata;
    wire        hready, hresp;
    wire        br_ro, br_rs, ot_ro, ot_rs;
    wire [7:0]  br_rd, ot_rd;
    wire        psel, penable, pwrite, pready, pslverr;
    wire [11:0] paddr;
    wire [7:0]  pwdata, prdata;

    // TB decoder: bridge at 0xF000-0xFFFF, the other slave everywhere else.
    wire sel_br = (haddr[15:12] == 4'hF);
    reg [1:0] owner = 2'd0;                // 0 none (after reset), 1 bridge, 2 other
    always @(posedge clk or negedge rstn)
        if (!rstn) owner <= 2'd0;
        else if (hready) owner <= sel_br ? 2'd1 : 2'd2;
    assign hready = (owner == 2'd1) ? br_ro : (owner == 2'd2) ? ot_ro : 1'b1;
    assign hresp  = (owner == 2'd1) ? br_rs : (owner == 2'd2) ? ot_rs : 1'b0;
    assign hrdata = (owner == 2'd1) ? br_rd : ot_rd;

    ahb_lite_master_bfm bfm (
        .clk(clk), .rstn(rstn), .haddr(haddr), .htrans(htrans), .hwrite(hwrite),
        .hsize(hsize), .hwdata(hwdata), .hrdata(hrdata), .hready(hready), .hresp(hresp));

    ahb_apb_bridge dut (
        .i_clk(clk), .i_rstn(rstn),
        .i_hsel(sel_br), .i_haddr(haddr), .i_htrans(htrans), .i_hwrite(hwrite),
        .i_hsize(hsize), .i_hwdata(hwdata), .i_hready(hready),
        .o_hreadyout(br_ro), .o_hresp(br_rs), .o_hrdata(br_rd),
        .o_psel(psel), .o_penable(penable), .o_paddr(paddr), .o_pwrite(pwrite),
        .o_pwdata(pwdata), .i_prdata(prdata), .i_pready(pready), .i_pslverr(pslverr));

    ahb_lite_slave_model #(.ID(ID_OTHER), .MIN_WAIT(0), .MAX_WAIT(4)) other (
        .clk(clk), .rstn(rstn), .hsel(!sel_br), .haddr(haddr), .htrans(htrans),
        .hwrite(hwrite), .hwdata(hwdata), .hready(hready),
        .hreadyout(ot_ro), .hresp(ot_rs), .hrdata(ot_rd));

    apb_slave_model #(.ID(ID_APB), .MIN_WAIT(0), .MAX_WAIT(APB_MAX_WAIT)) apb (
        .clk(clk), .rstn(rstn), .psel(psel), .penable(penable), .paddr(paddr),
        .pwrite(pwrite), .pwdata(pwdata), .pready(pready), .pslverr(pslverr), .prdata(prdata));

    apb_checker chk_apb (
        .clk(clk), .rstn(rstn), .psel(psel), .penable(penable), .paddr(paddr),
        .pwrite(pwrite), .pwdata(pwdata), .pready(pready));
    // OKAY waits of the bridge: SETUP + ACCESS = 2 + APB waits.
    ahb_lite_slave_checker #(.MAX_WAIT(2 + APB_MAX_WAIT)) chk_ahb (
        .clk(clk), .rstn(rstn), .hsel(sel_br), .htrans(htrans),
        .hready(hready), .hreadyout(br_ro), .hresp(br_rs));

    // ---------------- Reference model ----------------
    function automatic logic [7:0] data_of(input int id, input logic [15:0] a);
        return 8'((a ^ (a >> 8)) + id * 8'h35);
    endfunction

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $time);
    endtask

    // ---------------- Cycle monitors (coverage) ----------------
    int unsigned n_b2b = 0, n_cross_hold = 0, n_idle_br = 0, n_rst_setup = 0, n_rst_access = 0;
    bit tb_dp = 1'b0, tb_dp_br = 1'b0;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tb_dp = 1'b0;
        end else if (hready) begin
            // A bridge address phase taken in the last cycle of a bridge transfer.
            if (htrans[1] && sel_br && dut.r_state == 3'd3) n_b2b++;
            if (!htrans[1] && sel_br) n_idle_br++;
            tb_dp = htrans[1]; tb_dp_br = sel_br;
        end else if (htrans[1] && sel_br && tb_dp && !tb_dp_br) begin
            n_cross_hold++;               // bridge address phase held by the other slave
        end
    end

    // ---------------- Result checks ----------------
    typedef struct {
        logic [15:0] addr;
        bit          write;
        logic [7:0]  data;
        bit          resp;
    } exp_t;
    exp_t exp_other[$];
    int unsigned n_rd_ok = 0, n_wr_ok = 0, n_rd_err = 0, n_wr_err = 0, n_size_err = 0;
    int unsigned n_wait0 = 0, n_waitmax = 0, apb_k = 0, min_lat = 1000, max_lat = 0;

    task automatic check_results();
        for (int i = 0; i < bfm.results.size(); i++) begin
            // Local copies (XSim 2024.2 aborted on hierarchical struct-queue
            // reads in nested blocks).
            logic [15:0] a;
            logic [7:0]  wd, rd, pd, exp_rd;
            logic [11:0] pa;
            logic [2:0]  sz;
            bit          w, r, err, pw, pe;
            int unsigned wc, lat, pwt;
            exp_t        e;
            a = bfm.results[i].addr; w = bfm.results[i].write; sz = bfm.results[i].size;
            wd = bfm.results[i].wdata; rd = bfm.results[i].rdata; r = bfm.results[i].resp;
            wc = bfm.results[i].wait_cycles;
            err = (a[3:0] == 4'hF);
            if (a[15:12] != 4'hF) begin
                e.addr = a; e.write = w; e.resp = err;
                e.data = w ? wd : data_of(ID_OTHER, a);
                exp_other.push_back(e);
                if (r != err)
                    fail($sformatf("other HADDR=%h response %0d", a, r));
                else if (!err && !w && rd != e.data)
                    fail($sformatf("other HADDR=%h read %h, expected %h", a, rd, e.data));
            end else if (sz != 3'b000) begin
                n_size_err++;
                if (!r || wc != 1)
                    fail($sformatf("bridge HADDR=%h HSIZE=%0d: resp=%0d wait=%0d, expected ERROR after 1",
                         a, sz, r, wc));
            end else if (apb_k >= apb.log.size()) begin
                fail($sformatf("bridge HADDR=%h completed without an APB transfer", a));
            end else begin
                pa = apb.log[apb_k].addr; pw = apb.log[apb_k].write; pd = apb.log[apb_k].data;
                pe = apb.log[apb_k].err; pwt = apb.log[apb_k].waits;
                lat = 2 + pwt + (err ? 1 : 0);
                exp_rd = data_of(ID_APB, {4'h0, a[11:0]});
                if (pa != a[11:0] || pw != w || (w && pd != wd))
                    fail($sformatf("APB transfer %0d: PADDR=%h PWRITE=%0d data=%h, expected %h %0d %h",
                         apb_k, pa, pw, pd, a[11:0], w, wd));
                if (pe != err || r != err)
                    fail($sformatf("bridge HADDR=%h PSLVERR=%0d AHB resp=%0d, expected %0d", a, pe, r, err));
                else if (!err && !w && rd != exp_rd)
                    fail($sformatf("bridge HADDR=%h read %h, expected %h", a, rd, exp_rd));
                if (wc != lat)
                    fail($sformatf("bridge HADDR=%h wait %0d, expected %0d", a, wc, lat));
                if (!err) begin
                    if (lat < min_lat) min_lat = lat;
                    if (lat > max_lat) max_lat = lat;
                end
                if (pwt == 0) n_wait0++;
                if (pwt == APB_MAX_WAIT) n_waitmax++;
                if (w) begin if (err) n_wr_err++; else n_wr_ok++; end
                else begin if (err) n_rd_err++; else n_rd_ok++; end
                apb_k++;
            end
        end
        bfm.results.delete();
    endtask

    // ---------------- Stimulus ----------------
    task automatic wait_idle();
        int unsigned t = 0;
        do begin @(negedge clk); t++; end while (!bfm.idle() && t < 200000);
        if (!bfm.idle()) fail("BFM did not finish (hang)");
        repeat (2) @(negedge clk);
    endtask

    task automatic random_ops(input int n);
        repeat (n) begin
            int unsigned p, id;
            logic [15:0] a;
            bit [2:0] s;
            s = 3'b000;
            p = $urandom_range(99);
            if (p < 60) a = 16'hF000 + 16'($urandom_range(16'h0FFF, 0));
            else        a = 16'($urandom_range(16'hEFFF, 0));
            if (p < 5) s = 3'b001;
            id = bfm.push(a, $urandom_range(99) < 50, 8'($urandom),
                          ($urandom_range(99) < 70) ? 0 : $urandom_range(3, 1), s);
        end
    endtask

    initial begin
        int unsigned id;
        bit cov_ok;
        repeat (3) @(negedge clk);
        rstn = 1'b1;

        // 1. Directed: OKAY read/write, PSLVERR read/write, HSIZE error,
        //    back-to-back bridge transfers, bridge and other slave alternating.
        id = bfm.push(16'hFF00, 1'b0, 8'h00);
        id = bfm.push(16'hFF01, 1'b1, 8'h5A);
        id = bfm.push(16'hFF0F, 1'b0, 8'h00);
        id = bfm.push(16'hF00F, 1'b1, 8'hC3);
        id = bfm.push(16'hFF02, 1'b0, 8'h00, 0, 3'b001);
        for (int i = 0; i < 4; i++) id = bfm.push(16'hFF00 + 16'(i), 1'b0, 8'h00);
        for (int i = 0; i < 4; i++) begin
            id = bfm.push(16'hFF10 + 16'(i), 1'b1, 8'(i));
            id = bfm.push(16'h8000 + 16'(i), 1'b0, 8'h00);
        end
        wait_idle(); check_results();

        // 2. Random traffic: the master continues after ERROR, then cancels.
        bfm.cancel_on_error = 1'b0; random_ops(6000); wait_idle();
        bfm.cancel_on_error = 1'b1; random_ops(6000); wait_idle();
        check_results();

        // 3. Resets during APB SETUP or ACCESS (the APB transfer is aborted).
        repeat (20) begin
            int unsigned t;
            random_ops(40);
            repeat ($urandom_range(60, 3)) @(negedge clk);
            t = 0;
            while (!psel && t < 1000) begin @(negedge clk); t++; end
            if (psel) begin
                if (penable) n_rst_access++; else n_rst_setup++;
                rstn = 1'b0; @(negedge clk); rstn = 1'b1;
                @(negedge clk);
                if (psel || penable || !br_ro || br_rs) fail("bridge not idle after reset");
            end
        end
        wait_idle(); check_results();

        // Final checks.
        if (apb_k != apb.log.size())
            fail($sformatf("%0d APB transfers, %0d expected", apb.log.size(), apb_k));
        if (other.log.size() != exp_other.size())
            fail($sformatf("other slave saw %0d transfers, expected %0d", other.log.size(), exp_other.size()));
        else for (int k = 0; k < exp_other.size(); k++)
            if (other.log[k].addr != exp_other[k].addr || other.log[k].write != exp_other[k].write ||
                other.log[k].resp != exp_other[k].resp ||
                (!exp_other[k].resp && other.log[k].data != exp_other[k].data))
                fail($sformatf("other transfer %0d HADDR=%h differs", k, other.log[k].addr));
        fails += chk_apb.fails + chk_ahb.fails + other.fails;

        cov_ok = n_rd_ok && n_wr_ok && n_rd_err && n_wr_err && n_size_err && n_wait0 && n_waitmax &&
                 n_b2b && n_cross_hold && n_idle_br && bfm.n_cancel && n_rst_setup && n_rst_access &&
                 apb.n_junk_ready && min_lat == 2;
        $display("COVER bridge read_ok=%0d write_ok=%0d read_slverr=%0d write_slverr=%0d hsize_err=%0d | apb wait0=%0d wait%0d=%0d",
                 n_rd_ok, n_wr_ok, n_rd_err, n_wr_err, n_size_err, n_wait0, APB_MAX_WAIT, n_waitmax);
        $display("COVER b2b=%0d cross_hold=%0d idle_bridge=%0d cancels=%0d resets setup/access=%0d/%0d junk_pready=%0d latency=%0d..%0d other=%0d",
                 n_b2b, n_cross_hold, n_idle_br, bfm.n_cancel, n_rst_setup, n_rst_access,
                 apb.n_junk_ready, min_lat, max_lat, exp_other.size());
        if (!cov_ok) fail("coverage count below 1 (see COVER lines)");

        if (fails == 0)
            $display("APB_BRIDGE_PASS apb_transfers=%0d slverr=%0d hsize_err=%0d latency=%0d..%0d resets=%0d",
                     apb_k, n_rd_err + n_wr_err, n_size_err, min_lat, max_lat, n_rst_setup + n_rst_access);
        else
            $display("APB_BRIDGE_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #20ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
