`timescale 1ns/1ps
module tb_cpu8_reset;
    reg clk=0,rst=0,phase=0,ready=0;
    always #5 clk=~clk;
    wire halted,fault;
    wire [16:0] ia;
    wire [1:0] itrans,dtrans;
    wire [15:0] da,pc,x;
    wire [7:0] wd;
    wire dw;
    wire [31:0] regs;
    wire [3:0] flags;
    // Zero-wait instruction slave; the program changes across the reset.
    reg [15:0] i_word=0;
    wire [15:0] ins=phase ? (i_word==0 ? 16'h0b5a : 16'h0400) :
                            (i_word==0 ? 16'h1000 : 16'h0963);
    // Data slave: its data phase completes only when `ready` is set.
    reg d_dp=0;
    wire dready=!d_dp || ready;
    always @(posedge clk) begin
        if (!rst) begin i_word<=0; d_dp<=0; end
        else begin
            if (itrans[1]) i_word<=ia[16:1];
            if (dready) d_dp<=dtrans[1];
        end
    end
    cpu8_top dut(.i_clk(clk),.i_rst_n(rst),
        .o_i_haddr(ia),.o_i_htrans(itrans),
        .i_i_hrdata(ins),.i_i_hready(1'b1),.i_i_hresp(1'b0),
        .o_d_haddr(da),.o_d_htrans(dtrans),.o_d_hwrite(dw),.o_d_hwdata(wd),
        .i_d_hrdata(8'hee),.i_d_hready(dready),.i_d_hresp(1'b0),
        .o_halted(halted),.o_fault(fault),.o_pc(pc),.o_x(x),
        .o_flags(flags),.o_registers(regs));
    initial begin
        repeat(3) @(negedge clk);rst=1;
        wait(d_dp);
        repeat(3) @(negedge clk);
        if(halted || !d_dp || dut.r_m_valid!==1'b1) $fatal(1,"load should be waiting");
        rst=0;phase=1;
        repeat(2) @(negedge clk);
        if(dtrans!==2'b00 || itrans!==2'b00 || regs!==0 || flags!==0 || x!==0 ||
           pc!==0 || halted || fault)
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
