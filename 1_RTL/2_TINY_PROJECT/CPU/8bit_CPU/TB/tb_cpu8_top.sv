`timescale 1ns/1ps
module tb_cpu8_top;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, ir=0, dr=0;
    wire iq,dq,dw;
    wire [15:0] ia,da;
    wire [7:0] wd;
    reg [15:0] rom[0:65535];
    reg [7:0] ram[0:2047];
    wire [15:0] idata=rom[ia];
    integer ierror=-1, derror=-1, delay_mode=0, seed=0;
    integer cycles=0, stalls=0, overlap=0, reads=0,writes=0,rx=0,tx=0;
    wire ierr=(rom[ia]===16'hxxxx) || (ia==ierror);
    wire mapped=(da<2048) || (da==16'hff00 && !dw) ||
                (da==16'hff01 && dw) || (da==16'hff02 && !dw);
    wire derr=!mapped || (da==derror);
    wire [7:0] rd=da<2048 ? ram[da] :
                     (da==16'hff00 ? (8'h40+rx) : 8'h01);
    wire halted,fault,stall,ret,regwe;
    wire [2:0] code,stages;
    wire [15:0] pc,x,rpc,rins;
    wire [31:0] regs;
    wire [3:0] flags;
    wire [1:0] rr;
    wire [7:0] rv;
    cpu8_top dut (
        .i_clk(clk),.i_rst_n(rst_n),.o_i_req(iq),.o_i_addr(ia),
        .i_i_data(idata),.i_i_ready(ir),.i_i_error(ierr),
        .o_d_req(dq),.o_d_write(dw),.o_d_addr(da),.o_d_wdata(wd),
        .i_d_rdata(rd),.i_d_ready(dr),.i_d_error(derr),
        .o_halted(halted),.o_fault(fault),.o_fault_code(code),
        .o_pc(pc),.o_x(x),.o_flags(flags),.o_registers(regs),
        .o_stall(stall),.o_stage_valid(stages),
        .o_retire_valid(ret),.o_retire_pc(rpc),.o_retire_instruction(rins),
        .o_retire_reg_write(regwe),.o_retire_rd(rr),.o_retire_data(rv)
    );
    reg held=0, held_we;
    reg [15:0] held_addr;
    reg [7:0] held_data;
    reg reported=0;
    always @(negedge clk) begin
        ir=(delay_mode==0) || ((cycles+seed)%4 !=0);
        dr=(delay_mode==0) || ((cycles+seed)%5 ==0);
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            cycles=0;stalls=0;overlap=0;reads=0;writes=0;rx=0;tx=0;held=0;
        end else begin
            cycles=cycles+1;
            if (cycles>10000) $fatal(1,"WATCHDOG");
            if (held && (dq!==1'b1 || da!==held_addr || dw!==held_we || wd!==held_data))
                $fatal(1,"data request changed while waiting");
            held=dq && !dr;held_addr=da;held_we=dw;held_data=wd;
            if (stall) stalls=stalls+1;
            if (stages==3'b111) overlap=overlap+1;
            if (dq && dr && !derr) begin
                if (dw) begin
                    writes=writes+1;
                    if (da<2048) ram[da]<=wd;
                    else if (da==16'hff01) tx=tx+1;
                    $display("WRITE %04h %02h",da,wd);
                end else begin
                    reads=reads+1;
                    $display("READ %04h %02h",da,rd);
                    if (da==16'hff00) rx<=rx+1;
                end
            end
            #1;
            if (ret) $display("RET %04h %04h %08h %04h %01h %04h %0d %0d %02h",
                             rpc,rins,regs,x,flags,pc,regwe,rr,rv);
            if (halted && !reported) begin
                $display("END %0d %0d %0d %04h %08h %04h %01h %0d %0d %0d %0d %0d %0d",
                    cycles,halted,fault,pc,regs,x,flags,code,stalls,overlap,reads,writes,rx);
                reported=1;
            end
        end
    end
    integer fd,n,k,count=0;
    string manifest,name,romfile,datafile;
    initial begin
        if (!$value$plusargs("CASES=%s",manifest)) $fatal(1,"CASES argument missing");
        fd=$fopen(manifest,"r");
        if (!fd) $fatal(1,"cannot open cases manifest");
        while (!$feof(fd)) begin
            n=$fscanf(fd,"%s %s %s %d %d %d %d\n",
                      name,romfile,datafile,delay_mode,seed,ierror,derror);
            if (n==7) begin
                rst_n=0;reported=0;
                for(k=0;k<65536;k=k+1) rom[k]=16'hxxxx;
                for(k=0;k<2048;k=k+1) ram[k]=0;
                $readmemh(romfile,rom);
                $readmemh(datafile,ram);
                $display("CASE %s",name);
                repeat(3) @(negedge clk);
                rst_n=1;
                wait(reported);
                @(negedge clk);
                rst_n=0;
                count=count+1;
            end
        end
        $fclose(fd);
        $display("ALL_CASES_DONE %0d",count);
        $finish;
    end
endmodule
