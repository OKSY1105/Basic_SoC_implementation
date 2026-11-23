`timescale 1ns/1ps
module tb_cpu8_reset;
    reg clk=0,rst=0,ready=0;
    always #5 clk=~clk;
    wire halted,fault;
    wire [16:0] ia;
    wire [1:0] itrans,dtrans;
    wire [15:0] da,pc,x;
    wire [7:0] wd;
    wire dw;
    wire [31:0] regs;
    wire [3:0] flags;
    // Zero-wait instruction slave; the program changes across each reset.
    //   phase 0 -> 1: LD waiting -> reset -> LDI R3,5Ah / HALT.
    //   phase 2 -> 3 (v2): SP=0800h, LR=3, PUSH LRH waiting (write 07FFh)
    //                      -> reset -> CALL 3 / RET to HALT.
    //   phase 4 -> 5 (v2): SP=0800h, LR=3, POP LRH waiting (read 0800h)
    //                      -> reset -> LDI R3,5Ah / HALT.
    reg [2:0] phase=0;
    reg [15:0] i_word=0;
    function [15:0] program_word(input [2:0] p, input [15:0] w);
        case (p)
            3'd0: program_word=w==0 ? 16'h1000 : 16'h0963;      // LD R0,[X] / LDI R1,63h
            3'd2, 3'd4: program_word=w==0 ? 16'h4808 :         // LSPH 8
                                     w==1 ? 16'h4400 :         // LSPL 0 (SP=0800h)
                                     w==2 ? 16'h8004 :         // CALL 4 (LR=3)
                                     w==4 ? (p==3'd2 ? 16'h4d00 : 16'h5900) :  // PUSH LRH / POP LRH
                                     16'h0400;                 // HALT
            3'd3: program_word=w==0 ? 16'h8003 :               // CALL 3 (LR=1)
                               w==3 ? 16'h4000 : 16'h0400;     // RET to 1: HALT
            default: program_word=w==0 ? 16'h0b5a : 16'h0400;  // LDI R3,5Ah / HALT
        endcase
    endfunction
    wire [15:0] ins=program_word(phase,i_word);
    // Data slave: its data phase completes only when `ready` is set. The last
    // accepted address phase and the number of transfers since reset are kept.
    reg d_dp=0, d_write=0;
    reg [15:0] d_addr=0;
    integer d_transfers=0;
    wire dready=!d_dp || ready;
    always @(posedge clk) begin
        if (!rst) begin i_word<=0; d_dp<=0; end
        else begin
            if (itrans[1]) i_word<=ia[16:1];
            if (dready) d_dp<=dtrans[1];
            if (dready && dtrans[1]) begin
                d_addr<=da; d_write<=dw; d_transfers<=d_transfers+1;
            end
        end
    end
    // v2: after a reset in a stack data phase nothing is in flight and SP and
    // LR of both banks are 0.
    task check_v2_cleared(input string what);
        if(dtrans!==2'b00 || itrans!==2'b00 || regs!==0 || flags!==0 || x!==0 ||
           pc!==0 || halted || fault || dut.r_m_valid!==1'b0 ||
           dut.r_sp0!==16'h0000 || dut.r_sp1!==16'h0000 ||
           dut.r_lr0!==16'h0000 || dut.r_lr1!==16'h0000)
            $fatal(1,"reset did not clear in-flight state (%s): sp0=%h sp1=%h lr0=%h lr1=%h m_valid=%b",
                   what,dut.r_sp0,dut.r_sp1,dut.r_lr0,dut.r_lr1,dut.r_m_valid);
    endtask
    // v2: start phase p and hold its stack access (word 4) in the data phase.
    task start_stack_wait(input [2:0] p, input [15:0] instr, input [15:0] addr, input write);
        @(negedge clk);rst=0;ready=0;phase=p;
        repeat(2) @(negedge clk);rst=1;
        wait(d_dp);
        repeat(3) @(negedge clk);
        if(halted || fault || dut.r_m_valid!==1'b1 || dut.r_m_instruction!==instr ||
           d_addr!==addr || d_write!==write || dut.r_sp0!==16'h0800 || dut.r_lr0!==16'h0003)
            $fatal(1,"stack access should be waiting: instr=%h addr=%h write=%b sp0=%h lr0=%h",
                   dut.r_m_instruction,d_addr,d_write,dut.r_sp0,dut.r_lr0);
    endtask
    cpu8_top dut(.i_clk(clk),.i_rst_n(rst),
        .o_i_haddr(ia),.o_i_htrans(itrans),
        .i_i_hrdata(ins),.i_i_hready(1'b1),.i_i_hresp(1'b0),
        .o_d_haddr(da),.o_d_htrans(dtrans),.o_d_hwrite(dw),.o_d_hwdata(wd),
        .i_d_hrdata(8'hee),.i_d_hready(dready),.i_d_hresp(1'b0),
        .i_irq(1'b0),
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
        // v2: reset while PUSH LRH waits; then CALL/RET from SP=LR=0.
        start_stack_wait(3'd2,16'h4d00,16'h07ff,1'b1);
        rst=0;phase=3;
        repeat(2) @(negedge clk);
        check_v2_cleared("PUSH LRH");
        d_transfers=0;ready=1;rst=1;
        wait(halted);#1;
        if(fault || pc!==16'd2 || dut.r_lr0!==16'h0001 || dut.r_sp0!==16'h0000 || d_transfers!=0)
            $fatal(1,"after PUSH LRH reset: fault=%b pc=%h lr0=%h sp0=%h transfers=%0d",
                   fault,pc,dut.r_lr0,dut.r_sp0,d_transfers);
        // v2: reset while POP LRH waits (SP and the LR byte would be written).
        start_stack_wait(3'd4,16'h5900,16'h0800,1'b0);
        rst=0;phase=5;
        repeat(2) @(negedge clk);
        check_v2_cleared("POP LRH");
        d_transfers=0;ready=1;rst=1;
        wait(halted);#1;
        if(fault || regs!==32'h5a000000 || pc!==16'd2 || dut.r_lr0!==16'h0000 ||
           dut.r_sp0!==16'h0000 || d_transfers!=0)
            $fatal(1,"after POP LRH reset: fault=%b regs=%h pc=%h lr0=%h sp0=%h transfers=%0d",
                   fault,regs,pc,dut.r_lr0,dut.r_sp0,d_transfers);
        $display("RESET_PASS");
        $finish;
    end
    initial begin #10000;$fatal(1,"reset watchdog");end
endmodule
