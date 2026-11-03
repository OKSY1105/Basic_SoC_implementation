`timescale 1ns/1ps
// APB3 protocol checks on the master (bridge) side of one APB interface.
// Concurrent assertions are compiled only with APB_SVA (Vivado XSim).
// Each failure prints a line starting with FAIL and increments fails, which
// the TB adds to its own error count.
module apb_checker #(
    parameter integer ADDR_W = 12,
    parameter integer DATA_W = 8
) (
    input wire              clk,
    input wire              rstn,
    input wire              psel,
    input wire              penable,
    input wire [ADDR_W-1:0] paddr,
    input wire              pwrite,
    input wire [DATA_W-1:0] pwdata,
    input wire              pready
);
    int unsigned fails = 0;
`ifdef APB_SVA
    // 1. PENABLE only with PSEL.
    a_penable_psel: assert property (@(posedge clk) disable iff (!rstn)
        penable |-> psel)
        else begin $display("FAIL SVA a_penable_psel t=%0t", $time); fails++; end
    // 2. SETUP lasts one cycle and is followed by ACCESS.
    a_setup_access: assert property (@(posedge clk) disable iff (!rstn)
        psel && !penable |=> psel && penable)
        else begin $display("FAIL SVA a_setup_access t=%0t", $time); fails++; end
    // 3. Address, direction and write data are stable from SETUP to the end
    //    of ACCESS.
    a_access_stable: assert property (@(posedge clk) disable iff (!rstn)
        psel && penable |-> $stable(paddr) && $stable(pwrite) &&
                            (!pwrite || $stable(pwdata)))
        else begin $display("FAIL SVA a_access_stable t=%0t", $time); fails++; end
    // 4. ACCESS continues until PREADY.
    a_access_wait: assert property (@(posedge clk) disable iff (!rstn)
        psel && penable && !pready |=> psel && penable)
        else begin $display("FAIL SVA a_access_wait t=%0t", $time); fails++; end
    // 5. After the last ACCESS cycle PENABLE goes low (IDLE or a new SETUP).
    a_access_end: assert property (@(posedge clk) disable iff (!rstn)
        psel && penable && pready |=> !penable)
        else begin $display("FAIL SVA a_access_end t=%0t", $time); fails++; end
`endif
endmodule
