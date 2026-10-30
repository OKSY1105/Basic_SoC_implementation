`timescale 1ns/1ps
module tb_cpu8_reset;
    reg clk=0,rst=0,phase=0,ready=0;
    always #5 clk=~clk;
    wire iq,dq,dw,halted,fault;
    wire [15:0] ia,da,pc,x;
    wire [7:0] wd;
    wire [31:0] regs;
    wire [3:0] flags;
    wire [15:0] ins=phase ? (ia==0 ? 16'h0b5a : 16'h0400) :
                                      (ia==0 ? 16'h1000 : 16'h0963);
    cpu8_top dut(.i_clk(clk),.i_rst_n(rst),.o_i_req(iq),.o_i_addr(ia),
        .i_i_data(ins),.i_i_ready(1'b1),.i_i_error(1'b0),
        .o_d_req(dq),.o_d_write(dw),.o_d_addr(da),.o_d_wdata(wd),
        .i_d_rdata(8'hee),.i_d_ready(ready),.i_d_error(1'b0),
        .o_halted(halted),.o_fault(fault),.o_pc(pc),.o_x(x),
        .o_flags(flags),.o_registers(regs));
    initial begin
        repeat(3) @(negedge clk);rst=1;
        wait(dq);
        repeat(3) @(negedge clk);
        if(halted || !dq) $fatal(1,"load should be waiting");
        rst=0;phase=1;
        repeat(2) @(negedge clk);
        if(dq || regs!==0 || flags!==0 || x!==0 || pc!==0 || halted || fault)
            $fatal(1,"reset did not clear in-flight state");
        ready=1;rst=1;
        wait(halted);#1;
        if(fault || regs!==32'h5a000000 || pc!==16'd2)
            $fatal(1,"stale pre-reset instruction retired: regs=%h pc=%h",regs,pc);
        $display("RESET_PASS");
        $finish;
    end
    initial begin #10000;$fatal(1,"reset watchdog");end
endmodule
