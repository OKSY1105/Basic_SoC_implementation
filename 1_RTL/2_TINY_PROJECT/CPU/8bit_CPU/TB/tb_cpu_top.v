`timescale 1ns/1ps
// Testbench-only shared instruction/data byte array, NOT part of CPU.
module tb_cpu_top;
    reg i_clk = 1'b0;
    reg i_rst_n = 1'b0;
    wire o_mem_req, o_mem_we;
    wire [7:0] o_mem_addr, o_mem_wdata;
    wire [7:0] i_mem_rdata;
    wire i_mem_ready;
    reg [7:0] tb_bytes [0:255];
    reg [1:0] r_wait_count;
    reg r_prev_stall;
    reg [7:0] r_prev_addr, r_prev_wdata;
    reg r_prev_we;
    integer i, cycles, reads, writes;

    cpu_top dut (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .o_mem_req(o_mem_req), .o_mem_we(o_mem_we),
        .o_mem_addr(o_mem_addr), .o_mem_wdata(o_mem_wdata),
        .i_mem_rdata(i_mem_rdata), .i_mem_ready(i_mem_ready)
    );
    always #5 i_clk = ~i_clk;
    assign i_mem_rdata = tb_bytes[o_mem_addr];
    assign i_mem_ready = o_mem_req && (r_wait_count == 2'd2);

    // External response takes 2 cycles per access, then 1 transfer.
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_wait_count <= 2'd0;
        end else if (!o_mem_req || i_mem_ready) begin
            r_wait_count <= 2'd0;
        end else begin
            r_wait_count <= r_wait_count + 2'd1;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst_n) begin
            if (r_prev_stall && (!o_mem_req || o_mem_addr !== r_prev_addr ||
                                 o_mem_we !== r_prev_we || (o_mem_we && o_mem_wdata !== r_prev_wdata))) begin
                $display("FAIL: bus changed during wait state at cycle %0d", cycles);
                $fatal(1);
            end
            r_prev_stall <= o_mem_req && !i_mem_ready;
            r_prev_addr  <= o_mem_addr;
            r_prev_wdata <= o_mem_wdata;
            r_prev_we    <= o_mem_we;
            if (o_mem_req && i_mem_ready) begin
                if (o_mem_we) begin
                    tb_bytes[o_mem_addr] <= o_mem_wdata;
                    writes <= writes + 1;
                end else begin
                    reads <= reads + 1;
                end
            end
        end else begin
            r_prev_stall <= 1'b0;
        end
    end

    function [15:0] enc_r;
        input [2:0] rs, rt, rd, funct;
        begin enc_r = {4'h0, rs, rt, rd, funct}; end
    endfunction
    function [15:0] enc_i;
        input [3:0] opcode;
        input [2:0] rs, rt;
        input [5:0] imm;
        begin enc_i = {opcode, rs, rt, imm}; end
    endfunction
    function [15:0] enc_j;
        input [7:0] target;
        begin enc_j = {4'hA, 4'h0, target}; end
    endfunction
    task put_inst;
        input [7:0] addr;
        input [15:0] instruction;
        begin
            tb_bytes[addr]     = instruction[15:8];
            tb_bytes[addr + 8'd1] = instruction[7:0];
        end
    endtask

    initial begin
        r_wait_count = 2'd0;
        r_prev_stall = 1'b0;
        r_prev_addr  = 8'h00;
        r_prev_we    = 1'b0;
        r_prev_wdata = 8'h00;
        reads = 0;
        writes = 0;
        cycles = 0;
        for (i=0; i<256; i=i+1) tb_bytes[i] = 8'h00;

        // R format: AND=1 OR=2 NOR=3 ADD=4 SUB=5 SLT=6 SLTU=7
        put_inst(8'h00, enc_i(4'h3, 0, 1, 6'd10));  // R1 = 10
        put_inst(8'h02, enc_i(4'h3, 0, 2, 6'd20));  // R2 = 20
        put_inst(8'h04, enc_r(1, 2, 3, 4));       // R3 = 30
        put_inst(8'h06, enc_r(3, 1, 4, 5));       // R4 = 20
        put_inst(8'h08, enc_i(4'h1, 3, 5, 6'd6)); // R5 = 6
        put_inst(8'h0A, enc_i(4'h2, 5, 5, 6'd1)); // R5 = 7
        put_inst(8'h0C, enc_i(4'h4, 0, 6, 6'd32));// R6 = 32
        put_inst(8'h0E, enc_r(6, 6, 6, 4));       // R6 = 64
        put_inst(8'h10, enc_r(6, 6, 6, 4));       // R6 = 128
        put_inst(8'h12, enc_i(4'h8, 6, 3, 6'd0)); // SW R3,0(R6) -> [80]=30
        put_inst(8'h14, enc_i(4'h7, 6, 7, 6'd0)); // LW R7,0(R6) -> 30
        put_inst(8'h16, enc_i(4'h9, 7, 3, 6'd1)); // BEQ taken -> 1A
        put_inst(8'h18, enc_i(4'h3, 0, 4, 6'd0)); // skipped
        put_inst(8'h1A, enc_r(1, 2, 5, 6));       // signed SLT -> 1
        put_inst(8'h1C, enc_r(2, 1, 5, 7));       // unsigned SLTU -> 0
        put_inst(8'h1E, enc_i(4'h9, 1, 2, 6'd1)); // BEQ not taken
        put_inst(8'h20, enc_i(4'h3, 0, 5, 6'd5)); // R5 = 5
        put_inst(8'h22, enc_j(8'h28));             // J to 28
        put_inst(8'h24, enc_i(4'h3, 0, 4, 6'd1));// skipped
        put_inst(8'h26, enc_i(4'h3, 0, 4, 6'd2));// skipped
        put_inst(8'h28, enc_i(4'h3, 2, 2, 6'h3F));// ADDI -1; R2=19
        put_inst(8'h2A, enc_r(0, 0, 5, 3));       // NOR 0,0 = FF
        put_inst(8'h2C, enc_i(4'h5, 2, 5, 6'd20));// SLTI 19 < 20 -> 1
        put_inst(8'h2E, enc_i(4'h6, 2, 5, 6'd18));// SLTUI 19 < 18 -> 0
        put_inst(8'h30, enc_r(1, 2, 5, 1));       // AND -> 2
        put_inst(8'h32, enc_r(1, 2, 5, 2));       // OR -> 27
        put_inst(8'h34, enc_r(2, 1, 5, 6));       // SLT -> 0
        put_inst(8'h36, enc_r(1, 2, 5, 7));       // SLTU -> 1
        put_inst(8'h38, enc_i(4'h3, 0, 1, 6'h3F));// ADDI R1, -1 -> FF
        put_inst(8'h3A, enc_i(4'h4, 0, 1, 6'h3F));// ADDUI R1,63
        put_inst(8'h3C, enc_j(8'h42));             // J to 42
        put_inst(8'h3E, enc_i(4'h3, 0, 4, 6'd3));// skipped
        put_inst(8'h40, enc_i(4'h3, 0, 4, 6'd4));// skipped
        put_inst(8'h42, enc_j(8'h42));             // repeat indefinitely

        repeat (3) @(negedge i_clk);
        i_rst_n = 1'b1;
        for (cycles=0; cycles<850; cycles=cycles+1)
            @(negedge i_clk);

        if (dut.u_du.u_pc.o_pc !== 8'h42) begin
            $display("FAIL PC: expected 42, got %02h",dut.u_du.u_pc.o_pc);
            $fatal(1);
        end
        if (dut.u_du.u_irf.r_regs[0] !== 8'd0 ||
            dut.u_du.u_irf.r_regs[1] !== 8'd63 ||
            dut.u_du.u_irf.r_regs[2] !== 8'd19 ||
            dut.u_du.u_irf.r_regs[3] !== 8'd30 ||
            dut.u_du.u_irf.r_regs[4] !== 8'd20 ||
            dut.u_du.u_irf.r_regs[5] !== 8'd1 ||
            dut.u_du.u_irf.r_regs[6] !== 8'd128 ||
            dut.u_du.u_irf.r_regs[7] !== 8'd30) begin
            $display("FAIL registers: r0=%d r1=%d r2=%d r3=%d r4=%d r5=%d r6=%d r7=%d",
                dut.u_du.u_irf.r_regs[0], dut.u_du.u_irf.r_regs[1],
                dut.u_du.u_irf.r_regs[2], dut.u_du.u_irf.r_regs[3],
                dut.u_du.u_irf.r_regs[4], dut.u_du.u_irf.r_regs[5],
                dut.u_du.u_irf.r_regs[6], dut.u_du.u_irf.r_regs[7]);
            $fatal(1);
        end
        if (tb_bytes[8'h80] !== 8'd30 || writes !== 1) begin
            $display("FAIL store: data=%d writes=%d",tb_bytes[8'h80],writes);
            $fatal(1);
        end
        $display("PASS: CPU R/I/J instructions, signed immediates, BEQ, J, LW/SW, 2-cycle stalls");
        $display("      Reads=%0d writes=%0d data[80]=%0d PC=%02h", reads, writes, tb_bytes[8'h80], dut.u_du.u_pc.o_pc);
        $finish;
    end
endmodule
