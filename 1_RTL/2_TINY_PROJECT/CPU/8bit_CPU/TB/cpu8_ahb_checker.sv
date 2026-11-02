`timescale 1ns/1ps
// AHB-Lite master-side protocol checks for cpu8_top's two ports.
// Concurrent assertions are compiled only with CPU8_SVA (Vivado XSim);
// without it (e.g. Icarus) the module is empty and the TB-level checks remain.
// Each failure prints a line starting with FAIL, which run_cpu8_tests.py
// treats as an error.
module cpu8_ahb_checker (
    input wire clk, rst_n,
    input wire [1:0] i_htrans,
    input wire [16:0] i_haddr,
    input wire [2:0] i_hsize, i_hburst,
    input wire [3:0] i_hprot,
    input wire i_hwrite, i_hready, i_hresp,
    input wire [1:0] d_htrans,
    input wire [15:0] d_haddr,
    input wire [2:0] d_hsize, d_hburst,
    input wire [3:0] d_hprot,
    input wire d_hwrite,
    input wire [7:0] d_hwdata,
    input wire d_hready, d_hresp,
    input wire halted,          // o_halted
    input wire i_hold,          // instruction address phase held from last cycle
    input wire redirect,        // taken branch issuing from ID/EX
    input wire d_issue_mem,     // LD/ST issuing from ID/EX into MEM/WB
    input wire fetch_overflow   // fetch data landing with IF/ID and skid both full
);
`ifdef CPU8_SVA
    // Data-port data phase tracking (a transfer accepted at HREADY=1).
    reg d_dp=0, d_dp_write=0;
    always @(posedge clk)
        if (!rst_n) begin d_dp<=0; d_dp_write<=0; end
        else if (d_hready) begin d_dp<=d_htrans[1]; d_dp_write<=d_hwrite; end

    // 1. A NONSEQ that waits keeps its address and control (ERROR excepted).
    a_i_hold: assert property (@(posedge clk) disable iff (!rst_n)
        i_htrans==2'b10 && !i_hready |=> i_htrans==2'b10 && $stable(i_haddr))
        else begin $display("FAIL SVA a_i_hold t=%0t",$time); $fatal(1); end
    a_d_hold: assert property (@(posedge clk) disable iff (!rst_n)
        d_htrans==2'b10 && !d_hready && !d_hresp |=>
        d_htrans==2'b10 && $stable(d_haddr) && $stable(d_hwrite))
        else begin $display("FAIL SVA a_d_hold t=%0t",$time); $fatal(1); end
    // 2. Single transfers only, with the fixed attributes of each port.
    a_i_attr: assert property (@(posedge clk) disable iff (!rst_n)
        (i_htrans==2'b00 || i_htrans==2'b10) && i_hsize==3'b001 &&
        i_hburst==3'b000 && i_hprot==4'b0010 && !i_hwrite)
        else begin $display("FAIL SVA a_i_attr t=%0t",$time); $fatal(1); end
    a_d_attr: assert property (@(posedge clk) disable iff (!rst_n)
        (d_htrans==2'b00 || d_htrans==2'b10) && d_hsize==3'b000 &&
        d_hburst==3'b000 && d_hprot==4'b0011)
        else begin $display("FAIL SVA a_d_attr t=%0t",$time); $fatal(1); end
    // 3. A data address phase is accepted exactly when a LD/ST issues.
    a_d_issue: assert property (@(posedge clk) disable iff (!rst_n)
        (d_htrans[1] && d_hready) == d_issue_mem)
        else begin $display("FAIL SVA a_d_issue t=%0t",$time); $fatal(1); end
    // 4. Write data is stable through a waited data phase.
    a_d_wdata: assert property (@(posedge clk) disable iff (!rst_n)
        d_dp && d_dp_write && !d_hready |=> $stable(d_hwdata))
        else begin $display("FAIL SVA a_d_wdata t=%0t",$time); $fatal(1); end
    // 5. After the first ERROR cycle the next address phase is cancelled.
    a_d_err_cancel: assert property (@(posedge clk) disable iff (!rst_n)
        d_dp && !d_hready && d_hresp |=> d_htrans==2'b00)
        else begin $display("FAIL SVA a_d_err_cancel t=%0t",$time); $fatal(1); end
    // 6. Fetch data never arrives without a free slot.
    a_fetch_room: assert property (@(posedge clk) disable iff (!rst_n)
        !fetch_overflow)
        else begin $display("FAIL SVA a_fetch_room t=%0t",$time); $fatal(1); end
    // 6b. A held instruction address implies an empty ID, so no branch issues
    //     while it waits; the held address never has to be replaced.
    a_no_redirect_held: assert property (@(posedge clk) disable iff (!rst_n)
        !(i_hold && redirect))
        else begin $display("FAIL SVA a_no_redirect_held t=%0t",$time); $fatal(1); end
    // 7. After HALT/fault only an already-held instruction address may complete.
    a_halt_idle: assert property (@(posedge clk) disable iff (!rst_n)
        halted |-> d_htrans==2'b00 && (i_htrans==2'b00 || i_hold))
        else begin $display("FAIL SVA a_halt_idle t=%0t",$time); $fatal(1); end
`endif
endmodule
