`timescale 1ns/1ps
// Interrupt rules of cpu8_top. Concurrent assertions are compiled only with
// CPU8_SVA (Vivado XSim); each failure prints a line starting with FAIL.
module cpu8_irq_checker (
    input wire clk, rst_n,
    input wire irq,             // i_irq
    input wire ie, bank,        // r_ie, r_bank
    input wire int_take,        // interrupt entry this cycle
    input wire id_issue,        // ID/EX instruction issues this cycle
    input wire reti_issue,      // RETI issues this cycle
    input wire id_valid,        // ID/EX holds an instruction
    input wire m_valid, m_done, // MEM/WB occupied / completing
    input wire [1:0] d_htrans   // data port HTRANS
);
`ifdef CPU8_SVA
    // 1. Entry only when enabled, outside the handler, with a request and an
    //    instruction in ID/EX whose older MEM/WB work completes now (precise).
    a_int_cond: assert property (@(posedge clk) disable iff (!rst_n)
        int_take |-> irq && ie && !bank && id_valid && (!m_valid || m_done))
        else begin $display("FAIL SVA a_int_cond t=%0t",$time); $fatal(1); end
    // 2. The interrupted instruction does not issue.
    a_int_no_issue: assert property (@(posedge clk) disable iff (!rst_n)
        !(int_take && id_issue))
        else begin $display("FAIL SVA a_int_no_issue t=%0t",$time); $fatal(1); end
    // 3. No data address phase in the entry cycle (no access for a dropped LD/ST).
    a_int_no_dreq: assert property (@(posedge clk) disable iff (!rst_n)
        int_take |-> d_htrans==2'b00)
        else begin $display("FAIL SVA a_int_no_dreq t=%0t",$time); $fatal(1); end
    // 4. Entry switches to bank 1 with IE=0; RETI returns to bank 0 with IE=1.
    a_int_state: assert property (@(posedge clk) disable iff (!rst_n)
        int_take |=> bank && !ie)
        else begin $display("FAIL SVA a_int_state t=%0t",$time); $fatal(1); end
    a_reti_state: assert property (@(posedge clk) disable iff (!rst_n)
        reti_issue |=> !bank && ie)
        else begin $display("FAIL SVA a_reti_state t=%0t",$time); $fatal(1); end
    // 5. The bank changes only by entry or RETI.
    a_bank_change: assert property (@(posedge clk) disable iff (!rst_n)
        bank != $past(bank) |-> $past(int_take || reti_issue))
        else begin $display("FAIL SVA a_bank_change t=%0t",$time); $fatal(1); end
`endif
endmodule
