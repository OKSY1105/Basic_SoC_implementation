`timescale 1ns/1ps
module tb_cpu8_top;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0;
    reg [15:0] rom[0:65535];
    reg [7:0] ram[0:2047];
    integer ierror=-1, derror=-1, delay_mode=0, seed=0;
    integer cycles=0, stalls=0, overlap=0, reads=0,writes=0,rx=0,tx=0;
    // AHB-Lite instruction port (16-bit ROM) and data port (8-bit RAM/MMIO).
    wire [16:0] ia;
    wire [1:0] itrans,dtrans;
    wire [2:0] isize,iburst,dsize,dburst;
    wire [3:0] iprot,dprot;
    wire iwrite,ilock,dw,dlock;
    wire [15:0] da;
    wire [7:0] wd;
    reg [15:0] irdata=0;
    reg [7:0] drdata=0;
    reg iready=1, iresp=0, dready=1, dresp=0;
    wire halted,fault,stall,ret,regwe;
    wire [2:0] code,stages;
    wire [15:0] pc,x,rpc,rins;
    wire [31:0] regs;
    wire [3:0] flags;
    wire [1:0] rr;
    wire [7:0] rv;
    cpu8_top dut (
        .i_clk(clk),.i_rst_n(rst_n),
        .o_i_haddr(ia),.o_i_htrans(itrans),.o_i_hsize(isize),.o_i_hburst(iburst),
        .o_i_hprot(iprot),.o_i_hwrite(iwrite),.o_i_hmastlock(ilock),
        .i_i_hrdata(irdata),.i_i_hready(iready),.i_i_hresp(iresp),
        .o_d_haddr(da),.o_d_htrans(dtrans),.o_d_hsize(dsize),.o_d_hburst(dburst),
        .o_d_hprot(dprot),.o_d_hwrite(dw),.o_d_hmastlock(dlock),.o_d_hwdata(wd),
        .i_d_hrdata(drdata),.i_d_hready(dready),.i_d_hresp(dresp),
        .o_halted(halted),.o_fault(fault),.o_fault_code(code),
        .o_pc(pc),.o_x(x),.o_flags(flags),.o_registers(regs),
        .o_stall(stall),.o_stage_valid(stages),
        .o_retire_valid(ret),.o_retire_pc(rpc),.o_retire_instruction(rins),
        .o_retire_reg_write(regwe),.o_retire_rd(rr),.o_retire_data(rv)
    );
    // Protocol assertions run under XSim (CPU8_SVA); the module is empty otherwise.
    cpu8_ahb_checker chk (
        .clk(clk),.rst_n(rst_n),
        .i_htrans(itrans),.i_haddr(ia),.i_hsize(isize),.i_hburst(iburst),
        .i_hprot(iprot),.i_hwrite(iwrite),.i_hready(iready),.i_hresp(iresp),
        .d_htrans(dtrans),.d_haddr(da),.d_hsize(dsize),.d_hburst(dburst),
        .d_hprot(dprot),.d_hwrite(dw),.d_hwdata(wd),.d_hready(dready),.d_hresp(dresp),
        .halted(halted),.i_hold(dut.r_i_hold),.redirect(dut.w_redirect),
        .d_issue_mem(dut.w_id_issue && dut.w_memory && !dut.w_id_fault),
        .fetch_overflow(dut.r_id_valid && !dut.w_id_issue && dut.r_sk_valid && dut.w_if_land)
    );
    reg reported=0, default_demo=0;
    integer demo_retired=0;
    // Slave data-phase state. Mode 1 inserts wait states; an ERROR is always
    // HREADYOUT=0/HRESP=1 then HREADYOUT=1/HRESP=1 on consecutive cycles.
    reg i_dp=0, i_err=0, i_err2=0;
    reg [15:0] i_word=0;
    reg d_dp=0, d_err=0, d_err2=0, d_write=0;
    reg [15:0] d_a=0;
    // Master-side hold checks (simulator independent) and corner-case counts.
    reg i_held=0, d_held=0, d_wheld=0;
    reg [16:0] i_held_a;
    reg [15:0] d_held_a;
    reg d_held_w;
    reg [7:0] d_held_wd;
    integer cov_i_hold=0, cov_target_wait=0, cov_d_hold=0, cov_d_cancel=0, cov_skid=0;
    function automatic mapped(input [15:0] a, input w);
        mapped=(a<2048) || (a==16'hff00 && !w) || (a==16'hff01 && w) || (a==16'hff02 && !w);
    endfunction
    always @(negedge clk) begin
        if (!i_dp) begin iready=1; iresp=0; end
        else if (i_err2) begin iready=1; iresp=1; end
        else if (delay_mode!=0 && (cycles+seed)%4==0) begin iready=0; iresp=0; end
        else if (i_err) begin iready=0; iresp=1; end
        else begin iready=1; iresp=0; end
        irdata=rom[i_word];
        if (!d_dp) begin dready=1; dresp=0; end
        else if (d_err2) begin dready=1; dresp=1; end
        else if (delay_mode!=0 && (cycles+seed)%5!=0) begin dready=0; dresp=0; end
        else if (d_err) begin dready=0; dresp=1; end
        else begin dready=1; dresp=0; end
        drdata=d_a<2048 ? ram[d_a[10:0]] : (d_a==16'hff00 ? 8'h40+rx[7:0] : 8'h01);
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            cycles=0;stalls=0;overlap=0;reads=0;writes=0;rx=0;tx=0;demo_retired=0;
            i_dp<=0; i_err2<=0; d_dp<=0; d_err2<=0;
            i_held=0; d_held=0; d_wheld=0;
        end else begin
            cycles=cycles+1;
            if (cycles>10000) $fatal(1,"WATCHDOG");
            if (i_held && (itrans!==2'b10 || ia!==i_held_a))
                $fatal(1,"instruction address phase changed while waiting");
            if (d_held && (dtrans!==2'b10 || da!==d_held_a || dw!==d_held_w))
                $fatal(1,"data address phase changed while waiting");
            if (d_wheld && wd!==d_held_wd)
                $fatal(1,"write data changed during a waited data phase");
            i_held=(itrans==2'b10) && !iready; i_held_a=ia;
            d_held=(dtrans==2'b10) && !dready && !dresp; d_held_a=da; d_held_w=dw;
            d_wheld=d_dp && d_write && !dready; d_held_wd=wd;
            if (stall) stalls=stalls+1;
            if (stages==3'b111) overlap=overlap+1;
            if (itrans==2'b10 && !iready) cov_i_hold=cov_i_hold+1;
            if (dut.w_redirect && !iready) cov_target_wait=cov_target_wait+1;
            if (dtrans==2'b10 && d_dp && !dready && !dresp) cov_d_hold=cov_d_hold+1;
            if (dtrans==2'b10 && d_dp && !dready && dresp) cov_d_cancel=cov_d_cancel+1;
            if (dut.r_sk_valid) cov_skid=cov_skid+1;
            // Instruction slave: a new data phase starts when HREADY=1.
            if (i_dp && !iready && iresp) i_err2<=1;
            if (iready) begin
                i_dp<=itrans[1]; i_err2<=0;
                if (itrans[1]) begin
                    i_word<=ia[16:1];
                    i_err<=(rom[ia[16:1]]===16'hxxxx) || (ia[16:1]==ierror);
                end
            end
            // Data slave: side effects only on an OKAY completion.
            if (d_dp && !dready && dresp) d_err2<=1;
            if (dready) begin
                if (d_dp && !dresp) begin
                    if (d_write) begin
                        writes=writes+1;
                        if (d_a<2048) ram[d_a[10:0]]<=wd;
                        else if (d_a==16'hff01) tx=tx+1;
                        $display("WRITE %04h %02h",d_a,wd);
                    end else begin
                        reads=reads+1;
                        $display("READ %04h %02h",d_a,drdata);
                        if (d_a==16'hff00) rx<=rx+1;
                    end
                end
                d_dp<=dtrans[1]; d_err2<=0;
                if (dtrans[1]) begin
                    d_a<=da; d_write<=dw;
                    d_err<=!mapped(da,dw) || (da==derror);
                end
            end
            #1;
            if (ret) begin
                $display("RET %04h %04h %08h %04h %01h %04h %0d %0d %02h",
                         rpc,rins,regs,x,flags,pc,regwe,rr,rv);
                if (default_demo) begin
                    if (demo_retired>=4 || rpc!==demo_retired[15:0] ||
                        rins!==rom[demo_retired])
                        $fatal(1,"default demo instruction order mismatch");
                    demo_retired=demo_retired+1;
                end
            end
            if (halted && !reported) begin
                $display("END %0d %0d %0d %04h %08h %04h %01h %0d %0d %0d %0d %0d %0d",
                    cycles,halted,fault,pc,regs,x,flags,code,stalls,overlap,reads,writes,rx);
                if (default_demo) begin
                    if (fault!==1'b0 || code!==3'd0 || pc!==16'd4 ||
                        regs!==32'h0000141e || x!==16'd0 || flags!==4'd0 ||
                        demo_retired!=4 || reads!=0 || writes!=0)
                        $fatal(1,"default 10+20 demo failed: regs=%h pc=%h fault=%b",
                               regs,pc,fault);
                    $display("CPU8_DEMO_PASS: 10 + 20 = 30; R0=%0d R1=%0d PC=%0d",
                             regs[7:0],regs[15:8],pc);
                end
                reported=1;
            end
        end
    end
    integer fd,n,k,count=0;
    string manifest,name,romfile,datafile;
    task clear_case;
        begin
            rst_n=0;reported=0;
            for(k=0;k<65536;k=k+1) rom[k]=16'hxxxx;
            for(k=0;k<2048;k=k+1) ram[k]=0;
        end
    endtask
    task run_program;
        begin
            $display("CASE %s",name);
            repeat(3) @(negedge clk);
            rst_n=1;
            wait(reported);
            @(negedge clk);
            rst_n=0;
            count=count+1;
        end
    endtask
    initial begin
        if ($value$plusargs("CASES=%s",manifest)) begin
            // Optional external suite used by run_cpu8_tests.py.
            fd=$fopen(manifest,"r");
            if (!fd) $fatal(1,"cannot open cases manifest");
            while (!$feof(fd)) begin
                n=$fscanf(fd,"%s %s %s %d %d %d %d\n",
                          name,romfile,datafile,delay_mode,seed,ierror,derror);
                if (n==7) begin
                    clear_case;
                    $readmemh(romfile,rom);
                    $readmemh(datafile,ram);
                    run_program;
                end
            end
            $fclose(fd);
        end else begin
            // Default GUI demo: no arguments, memory files or UART input required.
            default_demo=1;
            clear_case;
            rom[0]=16'h080a; // LDI R0,10
            rom[1]=16'h0914; // LDI R1,20
            rom[2]=16'h2401; // ADD R0,R1
            rom[3]=16'h0400; // HALT
            name="first_add_builtin";
            run_program;
        end
        $display("COVER i_addr_held=%0d branch_target_waited=%0d d_addr_held=%0d d_error_cancel=%0d skid_used=%0d",
                 cov_i_hold,cov_target_wait,cov_d_hold,cov_d_cancel,cov_skid);
        $display("ALL_CASES_DONE %0d",count);
        $finish;
    end
endmodule
