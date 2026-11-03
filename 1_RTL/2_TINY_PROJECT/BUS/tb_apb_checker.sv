`timescale 1ns/1ps
// Self-test of apb_checker (compile with -d APB_SVA): each case must give an
// exact number of detections, 0 for every legal APB3 sequence.
//   Legal:   SETUP -> ACCESS, PREADY waits, back-to-back transfers (ACCESS ->
//            SETUP), PWDATA changing in a read, reset during SETUP/ACCESS.
//   Illegal: IDLE -> ACCESS with PADDR/PWRITE/PWDATA already stable
//            (VR-008-I1, with and without PREADY waits), PENABLE without
//            PSEL, two SETUP cycles, PADDR/PWRITE/PWDATA change in ACCESS,
//            ACCESS left before PREADY, ACCESS kept after PREADY.
// The checker prints one "FAIL SVA <name>" line per detection. Here those
// lines are intended (10 in all, each before its CASE line). A case that
// does not behave as expected prints "FAIL <case>:".
// Stimulus changes after the falling edge; the checker samples at the rising
// edge. Each case starts and ends with IDLE cycles so that |=> checks finish.
// Prints APB_CHECKER_PASS only if every case gives its expected count.
module tb_apb_checker;
    reg clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;

    reg        psel = 1'b0, penable = 1'b0, pwrite = 1'b0, pready = 1'b0;
    reg [11:0] paddr = 12'h000;
    reg [7:0]  pwdata = 8'h00;

    apb_checker chk (
        .clk(clk), .rstn(rstn), .psel(psel), .penable(penable),
        .paddr(paddr), .pwrite(pwrite), .pwdata(pwdata), .pready(pready));

    int unsigned errors = 0, n_legal = 0, n_illegal = 0, n_detect = 0, fails0 = 0;

    // One APB cycle. IDLE cycles keep the default PADDR/PWRITE/PWDATA, so a
    // transfer that uses the defaults has them stable before it starts.
    task automatic cyc(input bit s, input bit e, input bit r,
                       input logic [11:0] a = 12'h123, input bit w = 1'b1,
                       input logic [7:0] d = 8'ha5);
        @(negedge clk);
        psel = s; penable = e; pready = r; paddr = a; pwrite = w; pwdata = d;
    endtask

    task automatic idle(input int unsigned n);
        repeat (n) cyc(1'b0, 1'b0, 1'b0);
    endtask

    task automatic start_case();
        idle(3);
        fails0 = chk.fails;
    endtask

    task automatic end_case(input string name, input int unsigned expect_n);
        int unsigned got;
        idle(3);
        got = chk.fails - fails0;
        if (expect_n == 0) n_legal++; else n_illegal++;
        n_detect += got;
        if (got != expect_n) begin
            errors++;
            $display("FAIL %s: expected %0d detections, got %0d", name, expect_n, got);
        end else $display("CASE %s detections=%0d", name, got);
    endtask

    initial begin
        idle(3);
        @(negedge clk) rstn = 1'b1;

        // Legal sequences.
        start_case(); cyc(1,0,0); cyc(1,1,1);
        end_case("legal_single", 0);
        start_case(); cyc(1,0,0); cyc(1,1,0); cyc(1,1,0); cyc(1,1,1);
        cyc(1,0,0,12'h456,1'b0); cyc(1,1,1,12'h456,1'b0);
        end_case("legal_waits_back_to_back", 0);
        start_case(); cyc(1,0,0,12'h789,1'b0,8'h11); cyc(1,1,1,12'h789,1'b0,8'h22);
        end_case("legal_read_pwdata_change", 0);
        start_case(); cyc(1,0,0); cyc(1,1,0);
        @(negedge clk) begin rstn = 1'b0; psel = 1'b0; penable = 1'b0; end
        @(negedge clk) rstn = 1'b1;
        cyc(1,0,0); cyc(1,1,1);
        end_case("legal_reset_in_access", 0);
        start_case(); cyc(1,0,0);
        @(negedge clk) begin rstn = 1'b0; psel = 1'b0; end
        @(negedge clk) rstn = 1'b1;
        cyc(1,0,0); cyc(1,1,0); cyc(1,1,1);
        end_case("legal_reset_in_setup", 0);

        // Illegal sequences: expected detections (checks of apb_checker.sv).
        start_case(); cyc(1,1,1);                                     // 6
        end_case("idle_to_access_stable", 1);
        start_case(); cyc(1,1,0); cyc(1,1,0); cyc(1,1,1);             // 6
        end_case("idle_to_access_stable_wait", 1);
        start_case(); cyc(0,1,0);                                     // 1
        end_case("penable_without_psel", 1);
        start_case(); cyc(1,0,0); cyc(1,0,0); cyc(1,1,1);             // 2
        end_case("two_setup_cycles", 1);
        start_case(); cyc(1,0,0,12'h123); cyc(1,1,1,12'h124);         // 3
        end_case("paddr_change_in_access", 1);
        start_case(); cyc(1,0,0,12'h123,1'b1); cyc(1,1,1,12'h123,1'b0);    // 3
        end_case("pwrite_change_in_access", 1);
        start_case(); cyc(1,0,0,12'h123,1'b1,8'ha5); cyc(1,1,1,12'h123,1'b1,8'h5a);  // 3
        end_case("pwdata_change_in_write", 1);
        start_case(); cyc(1,0,0); cyc(1,1,0);                         // 4
        end_case("access_left_before_pready", 1);
        start_case(); cyc(1,0,0); cyc(1,1,1); cyc(1,1,1);             // 5 and 6
        end_case("access_kept_after_pready", 2);

        if (errors == 0)
            $display("APB_CHECKER_PASS legal=%0d illegal=%0d detections=%0d",
                     n_legal, n_illegal, n_detect);
        else
            $display("APB_CHECKER_FAIL errors=%0d", errors);
        $finish;
    end
endmodule
