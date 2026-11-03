`timescale 1ns/1ps
// Unit TB for reset_sync (STAGES = 2 and 3).
// Checks (reference rules written here):
//   - Assertion is asynchronous: o_rst_n is low in the same time step as the
//     falling edge of i_rst_n, also at power-up and while the clock stops.
//   - While i_rst_n is low, o_rst_n is low at every clock edge.
//   - Deassertion is synchronous: o_rst_n rises only at a rising clock edge,
//     on exactly the STAGES-th rising edge after i_rst_n rises.
//   - A new assertion during the release sequence starts it again.
//   - Users of the STAGES=2 output: a synchronous-reset counter (like the
//     CPU) and an asynchronous-reset counter are both cleared by every pulse,
//     even one shorter than a clock period, and leave reset in the same
//     cycle (equal counts).
// Scenarios: power-up, release 0.1 ns after and before an edge, glitches,
// reassertion during the release, 200 random pulses, stopped clock.
// Prints RESET_SYNC_PASS only if no check failed and every case occurred.
module tb_reset_sync;
    reg clk = 1'b0, clk_en = 1'b1;
    always begin #5; if (clk_en) clk = ~clk; end    // rising edges at 5 + 10k ns
    reg rst_in;                                     // X until 0.1 ns (power-up)
    wire out2, out3;

    reset_sync #(.STAGES(2)) u2 (.i_clk(clk), .i_rst_n(rst_in), .o_rst_n(out2));
    reset_sync #(.STAGES(3)) u3 (.i_clk(clk), .i_rst_n(rst_in), .o_rst_n(out3));

    // Users of out2: synchronous reset (like cpu8_top) and asynchronous reset.
    reg [15:0] c_sync = 16'hFFFF, c_async = 16'hFFFF;
    always @(posedge clk) if (!out2) c_sync <= 16'd0; else c_sync <= c_sync + 16'd1;
    always @(posedge clk or negedge out2) if (!out2) c_async <= 16'd0; else c_async <= c_async + 16'd1;

    int unsigned fails = 0;
    task automatic fail(input string msg);
        fails++;
        if (fails <= 20) $display("FAIL %s t=%0t", msg, $realtime);
    endtask

    realtime t_edge = -1.0;
    always @(posedge clk) t_edge = $realtime;

    // Asynchronous assertion.
    always @(negedge rst_in) begin
        #0.001;
        if (out2 !== 1'b0 || out3 !== 1'b0) fail("output not low right after assertion");
    end
    // Low at every clock edge while the input is low. Sampled 0.505 ns after
    // the edge: stimulus times are multiples of 0.01 ns, so they never fall in
    // the same time step as this check.
    always @(posedge clk) begin
        #0.505;
        if (rst_in !== 1'b1 && (out2 !== 1'b0 || out3 !== 1'b0)) fail("output high while input low");
    end
    // Release only at a rising clock edge.
    always @(posedge out2) if (out2 === 1'b1 && $realtime != t_edge) fail("STAGES=2 output rose between edges");
    always @(posedge out3) if (out3 === 1'b1 && $realtime != t_edge) fail("STAGES=3 output rose between edges");

    int unsigned n_pulses = 0, n_glitch = 0, n_near_after = 0, n_near_before = 0;
    int unsigned n_reassert = 0, n_stopped = 0;

    // Waits for the outputs after i_rst_n has risen (or the clock restarted):
    // STAGES=2 must rise on the 2nd edge, STAGES=3 on the 3rd, and the two
    // users must leave reset together.
    task automatic check_release(input string what);
        int unsigned n;
        int e2, e3;
        n = 0; e2 = -1; e3 = -1;
        while (e3 < 0 && n < 10) begin
            @(posedge clk); n++;
            #0.5;
            if (out2 === 1'b1 && e2 < 0) e2 = n;
            if (out3 === 1'b1 && e3 < 0) e3 = n;
        end
        if (e2 != 2 || e3 != 3)
            fail($sformatf("%s: release on edges %0d/%0d, expected 2/3", what, e2, e3));
        if (c_sync !== c_async || c_sync > 16'd2)
            fail($sformatf("%s: users sync=%0d async=%0d after release", what, c_sync, c_async));
    endtask

    // One pulse of the given length; the release phase follows from it.
    task automatic pulse(input realtime len, input string what);
        realtime t0;
        if (c_sync < 16'd5 || c_async < 16'd5) fail($sformatf("%s: users not running before the pulse", what));
        t0 = $realtime;
        rst_in = 1'b0;
        #(len);
        if (t_edge < t0) n_glitch++;                // no rising edge while low
        rst_in = 1'b1;
        n_pulses++;
        check_release(what);
        repeat (20) @(posedge clk);
    endtask

    initial begin
        #0.1 rst_in = 1'b0;                         // power-up: X -> 0
        #0.1;
        if (out2 !== 1'b0 || out3 !== 1'b0) fail("power-up: output not low");
        repeat (3) @(posedge clk);
        #2 rst_in = 1'b1;
        check_release("power-up");
        repeat (20) @(posedge clk);

        // Release 0.1 ns after and 0.1 ns before a rising edge.
        @(posedge clk); #2 rst_in = 1'b0;
        @(posedge clk); #0.1 rst_in = 1'b1; n_near_after++; n_pulses++;
        check_release("release 0.1 ns after an edge");
        repeat (20) @(posedge clk);
        @(posedge clk); #2 rst_in = 1'b0;
        @(posedge clk); #9.9 rst_in = 1'b1; n_near_before++; n_pulses++;
        check_release("release 0.1 ns before an edge");
        repeat (20) @(posedge clk);

        // Glitches between two edges.
        @(posedge clk); #3; pulse(0.3, "0.3 ns glitch");
        @(posedge clk); #1; pulse(2.0, "2 ns glitch");

        // Reassertion during the release sequence.
        @(posedge clk); #2 rst_in = 1'b0;
        @(posedge clk); #2 rst_in = 1'b1;
        @(posedge clk); #2 rst_in = 1'b0;            // after the first release edge
        n_reassert++;
        #0.001 if (out2 !== 1'b0 || out3 !== 1'b0) fail("reassertion: output not low");
        @(posedge clk); #2 rst_in = 1'b1; n_pulses++;
        check_release("reassertion");
        repeat (20) @(posedge clk);

        // Random pulse lengths and phases.
        repeat (200) begin
            realtime len;
            #($urandom_range(997, 3) / 100.0);
            len = $urandom_range(4000, 30) / 100.0;  // 0.3 .. 40 ns
            pulse(len, "random");
        end

        // Stopped clock: assertion without a clock, no release until it runs.
        @(negedge clk); clk_en = 1'b0;
        #7 rst_in = 1'b0;
        #0.001 if (out2 !== 1'b0 || out3 !== 1'b0) fail("stopped clock: output not low");
        #13 rst_in = 1'b1;
        #50;
        if (out2 !== 1'b0 || out3 !== 1'b0) fail("stopped clock: released without a clock");
        clk_en = 1'b1; n_stopped++; n_pulses++;
        check_release("clock restarted");

        if (!(n_glitch >= 2 && n_near_after && n_near_before && n_reassert && n_stopped && n_pulses >= 200))
            fail("coverage count below 1");
        $display("COVER pulses=%0d glitches_without_edge=%0d near_after=%0d near_before=%0d reassert=%0d stopped_clock=%0d",
                 n_pulses, n_glitch, n_near_after, n_near_before, n_reassert, n_stopped);
        if (fails == 0) $display("RESET_SYNC_PASS pulses=%0d glitches=%0d", n_pulses, n_glitch);
        else $display("RESET_SYNC_FAIL failures=%0d", fails);
        $finish;
    end

    initial begin
        #1ms;
        $display("FAIL timeout");
        $finish;
    end
endmodule
