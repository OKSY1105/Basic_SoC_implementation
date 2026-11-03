`timescale 1ns/1ps
module tb_cpu8_top;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0;
    reg [15:0] rom[0:65535];
    reg [7:0] ram[0:2047];
    integer ierror=-1, derror=-1, delay_mode=0, seed=0;
    integer cycles=0, stalls=0, overlap=0, reads=0,writes=0,rx=0,tx=0;
    // Interrupt source: rises at irq_start + k*irq_period (k < irq_count) and
    // falls when the program writes 0xFF04 (acknowledge).
    integer irq_start=0, irq_period=1, irq_count=0, irq_fired=0;
    reg irq=0;
    localparam integer LAT_LIMIT=64;
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
    wire rbk, irqact;
    cpu8_top dut (
        .i_clk(clk),.i_rst_n(rst_n),
        .o_i_haddr(ia),.o_i_htrans(itrans),.o_i_hsize(isize),.o_i_hburst(iburst),
        .o_i_hprot(iprot),.o_i_hwrite(iwrite),.o_i_hmastlock(ilock),
        .i_i_hrdata(irdata),.i_i_hready(iready),.i_i_hresp(iresp),
        .o_d_haddr(da),.o_d_htrans(dtrans),.o_d_hsize(dsize),.o_d_hburst(dburst),
        .o_d_hprot(dprot),.o_d_hwrite(dw),.o_d_hmastlock(dlock),.o_d_hwdata(wd),
        .i_d_hrdata(drdata),.i_d_hready(dready),.i_d_hresp(dresp),
        .i_irq(irq),
        .o_halted(halted),.o_fault(fault),.o_fault_code(code),
        .o_pc(pc),.o_x(x),.o_flags(flags),.o_registers(regs),
        .o_stall(stall),.o_stage_valid(stages),
        .o_retire_valid(ret),.o_retire_pc(rpc),.o_retire_instruction(rins),
        .o_retire_reg_write(regwe),.o_retire_rd(rr),.o_retire_data(rv),
        .o_retire_bank(rbk),.o_irq_active(irqact)
    );
    cpu8_irq_checker ichk (
        .clk(clk),.rst_n(rst_n),.irq(irq),.ie(dut.r_ie),.bank(dut.r_bank),
        .int_take(dut.w_int_take),.id_issue(dut.w_id_issue),
        .reti_issue(dut.w_reti_issue),.id_valid(dut.r_id_valid),
        .m_valid(dut.r_m_valid),.m_done(dut.w_m_done),.d_htrans(dtrans)
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
    // Interrupt coverage and request-to-entry latency.
    integer cov_int=0, cov_int_mem=0, cov_int_id_mem=0, cov_int_id_branch=0;
    integer cov_int_dheld=0, cov_int_reentry=0, cov_irq_masked=0, cov_irq_in_handler=0;
    integer lat=0, max_lat=0;
    reg int_now=0, last_ret_reti=0, elig=0;
    function automatic mapped(input [15:0] a, input w);
        mapped=(a<2048) || (a==16'hff00 && !w) || (a==16'hff01 && w) || (a==16'hff02 && !w) ||
               (a==16'hff04 && w);
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
            irq<=0; irq_fired=0; lat=0; last_ret_reti=0;
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
            // Interrupt entry (pre-edge values) and latency while eligible.
            int_now=dut.w_int_take;
            elig=irq && dut.r_ie && !dut.r_bank && !halted;
            if (int_now) begin
                cov_int=cov_int+1;
                if (dut.r_m_valid && dut.r_m_memory) cov_int_mem=cov_int_mem+1;
                if (dut.w_memory) cov_int_id_mem=cov_int_id_mem+1;
                if (dut.w_branch) cov_int_id_branch=cov_int_id_branch+1;
            end
            if (elig && dut.r_d_held) cov_int_dheld=cov_int_dheld+1;
            if (irq && !dut.r_ie && !dut.r_bank && !halted) cov_irq_masked=cov_irq_masked+1;
            if (irq && dut.r_bank) cov_irq_in_handler=cov_irq_in_handler+1;
            if (int_now || !elig) lat=0; else lat=lat+1;
            if (lat>max_lat) max_lat=lat;
            if (lat>LAT_LIMIT) $fatal(1,"interrupt not taken within %0d cycles",LAT_LIMIT);
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
                        else if (d_a==16'hff04) irq<=0;   // acknowledge
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
            // Interrupt source (a new request wins over an acknowledge).
            if (irq_count>0 && cycles>=irq_start && (cycles-irq_start)%irq_period==0 &&
                irq_fired<irq_count) begin
                irq<=1; irq_fired=irq_fired+1;
            end
            #1;
            if (ret) begin
                // Registers, X and FLAGS of the bank the instruction ran in.
                $display("RET %04h %04h %08h %04h %01h %04h %0d %0d %02h",
                         rpc,rins,rbk ? dut.w_registers_irq : regs,
                         rbk ? dut.r_x1 : x,rbk ? dut.r_flags1 : flags,pc,regwe,rr,rv);
                last_ret_reti=(rins[15:10]==6'h1b);
                if (default_demo) begin
                    if (demo_retired>=4 || rpc!==demo_retired[15:0] ||
                        rins!==rom[demo_retired])
                        $fatal(1,"default demo instruction order mismatch");
                    demo_retired=demo_retired+1;
                end
            end
            // Entry after the instructions retired at this edge; EPC is updated.
            if (int_now) begin
                $display("INT %04h",dut.r_epc);
                if (last_ret_reti) cov_int_reentry=cov_int_reentry+1;
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
                n=$fscanf(fd,"%s %s %s %d %d %d %d %d %d %d\n",
                          name,romfile,datafile,delay_mode,seed,ierror,derror,
                          irq_start,irq_period,irq_count);
                if (n==10) begin
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
        if (cov_int!=0)
            $display("COVER int_taken=%0d int_after_mem_wait=%0d int_dropped_ldst=%0d int_dropped_branch=%0d int_deferred_by_held_d=%0d int_reentry_after_reti=%0d irq_masked=%0d irq_in_handler=%0d",
                     cov_int,cov_int_mem,cov_int_id_mem,cov_int_id_branch,cov_int_dheld,
                     cov_int_reentry,cov_irq_masked,cov_irq_in_handler);
        $display("IRQ_LATENCY max=%0d limit=%0d",max_lat,LAT_LIMIT);
        $display("ALL_CASES_DONE %0d",count);
        $finish;
    end
endmodule
