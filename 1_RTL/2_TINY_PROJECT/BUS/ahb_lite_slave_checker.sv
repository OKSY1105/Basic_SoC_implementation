`timescale 1ns/1ps
// AHB-Lite slave-side response checks. Connect it to one slave (its HSEL and
// HREADYOUT) or to a whole interconnect seen from the master (HSEL tied to 1,
// HREADYOUT = the HREADY returned to the master).
// Concurrent assertions are compiled only with AHB_LITE_SVA (Vivado XSim).
// Each failure prints a line starting with FAIL and increments fails, which
// the TB adds to its own error count.
module ahb_lite_slave_checker #(
    parameter integer MAX_WAIT = 16     // longest allowed OKAY wait
) (
    input wire       clk,
    input wire       rstn,
    input wire       hsel,
    input wire [1:0] htrans,
    input wire       hready,            // bus HREADY
    input wire       hreadyout,
    input wire       hresp
);
    int unsigned fails = 0;
`ifdef AHB_LITE_SVA
    // Data phase owned by this slave, and whether it carries a transfer.
    reg r_sel = 1'b0, r_dp = 1'b0;
    int unsigned r_wait = 0;
    always @(posedge clk or negedge rstn)
        if (!rstn) begin r_sel <= 1'b0; r_dp <= 1'b0; r_wait <= 0; end
        else begin
            if (hready) begin r_sel <= hsel; r_dp <= hsel && htrans[1]; end
            r_wait <= (r_dp && !hreadyout && !hresp) ? r_wait + 1 : 0;
        end

    // 1. Selected for IDLE (or not yet selected after reset): zero-wait OKAY.
    a_idle_okay: assert property (@(posedge clk) disable iff (!rstn)
        r_sel && !r_dp |-> hreadyout && !hresp)
        else begin $display("FAIL SVA a_idle_okay t=%0t", $time); fails++; end
    // 2. ERROR is two cycles: HREADYOUT low then high, HRESP high in both.
    a_err_second: assert property (@(posedge clk) disable iff (!rstn)
        r_dp && hresp && !hreadyout |=> hresp && hreadyout)
        else begin $display("FAIL SVA a_err_second t=%0t", $time); fails++; end
    a_err_first: assert property (@(posedge clk) disable iff (!rstn)
        r_dp && hresp && hreadyout |-> $past(r_dp && hresp && !hreadyout))
        else begin $display("FAIL SVA a_err_first t=%0t", $time); fails++; end
    // 3. OKAY waits are bounded.
    a_wait_bound: assert property (@(posedge clk) disable iff (!rstn)
        r_wait <= MAX_WAIT)
        else begin $display("FAIL SVA a_wait_bound t=%0t", $time); fails++; end
`endif
endmodule
