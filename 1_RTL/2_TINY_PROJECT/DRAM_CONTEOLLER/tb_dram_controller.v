`timescale 1ns / 1ps

// Default, self-checking test: no files, CASES, or user input are required.
// Compile THIS file, dram_controller.v, and the existing ../DRAM/dram.v.
// Select tb_dram_controller as simulation top and run until $finish.
// Optional alternate top: tb_dram_controller_alt (CL=10, CWL=11, tRCD=12).
// The TB preloads the model array with a nonzero reference pattern solely so
// that preservation of the seven neighboring bytes can be checked. Neither
// the controller nor reset initializes the real/model memory contents.
module tb_dram_controller #(
    parameter integer T_RCD_CYCLES = 9,
    parameter integer CL_CYCLES = 9,
    parameter integer CWL_CYCLES = 10
);
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg req = 0;
    reg write = 0;
    reg [10:0] addr = 0;
    reg [7:0] wdata = 0;
    wire ready, error, busy, initialized;
    wire [7:0] rdata;
    wire ck_t, ck_c, cke, csn, actn;
    wire [1:0] bg, ba;
    wire [17:0] a;
    tri [7:0] dq;
    tri dqs_t, dqs_c;

    dram_controller #(
        .T_RCD_CYCLES(T_RCD_CYCLES),
        .CL_CYCLES(CL_CYCLES), .CWL_CYCLES(CWL_CYCLES)
    ) dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_req(req), .i_write(write),
        .i_addr(addr), .i_wdata(wdata), .o_ready(ready), .o_rdata(rdata),
        .o_error(error), .o_busy(busy), .o_initialized(initialized),
        .o_dram_ck_t(ck_t), .o_dram_ck_c(ck_c), .o_dram_cke(cke),
        .o_dram_csn(csn), .o_dram_actn(actn), .o_dram_bg(bg),
        .o_dram_ba(ba), .o_dram_a(a), .io_dram_dq(dq),
        .io_dram_dqs_t(dqs_t), .io_dram_dqs_c(dqs_c)
    );

    // The unmodified repository device model is the memory under test.
    dram memory_model (
        .ck_t(ck_t), .ck_c(ck_c), .cke(cke), .csn(csn), .actn(actn),
        .bg(bg), .ba(ba), .a(a), .dq(dq), .dqs_t(dqs_t), .dqs_c(dqs_c)
    );

    reg [7:0] expected [0:2047];
    integer checks = 0;
    integer host_completions = 0;
    integer write_commands = 0;
    integer read_commands = 0;
    integer model_commits = 0;
    integer model_cycles = 0;
    integer last_act_cycle = -100000;
    integer index, lane, row, col, before_completions, before_writes;
    reg [7:0] value;
    wire [4:0] opcode = {csn, actn, a[16], a[15], a[14]};

    task fail;
        input [8*160-1:0] message;
        begin
            $display("DRAM_CONTROLLER_FAIL: %0s time=%0t addr=%03h state=%0d cycle=%0d",
                     message, $time, addr, dut.r_state, dut.r_cycle);
            $fatal(1, "DRAM_CONTROLLER_FAIL");
            $finish;
        end
    endtask

    // These monitors observe command pins and the device's actual commit,
    // independently of the controller's wait counters and RMW buffer.
    always @(posedge ck_t) begin
        model_cycles = model_cycles + 1;
        if (opcode == 5'b00111) last_act_cycle = model_cycles;
        if (opcode == 5'b01100 || opcode == 5'b01101) begin
            if (model_cycles-last_act_cycle < T_RCD_CYCLES)
                fail("ACT-to-column command violated tRCD");
            if (opcode == 5'b01100) write_commands = write_commands + 1;
            else read_commands = read_commands + 1;
        end
        if (memory_model.data_write === 1'b1)
            model_commits = model_commits + 1;
    end

    always @(posedge clk) begin
        if (rst_n && req && ready) host_completions = host_completions + 1;
        if (!rst_n && ready === 1'b1) fail("completion during reset");
        if (dut.r_dq_oe === 1'b1 && memory_model.dq_oe === 1'b1)
            fail("controller/model DQ contention");
    end

    task wait_initialized;
        integer timeout;
        begin
            timeout = 0;
            while (initialized !== 1'b1 || busy !== 1'b0) begin
                @(negedge clk);
                timeout = timeout + 1;
                if (timeout > 3000) fail("initialization timeout");
            end
            if (memory_model.tCL !== CL_CYCLES ||
                memory_model.tCWL !== CWL_CYCLES)
                fail("MRS latency configuration mismatch");
            checks = checks + 1;
        end
    endtask

    task check_word;
        input integer byte_address;
        integer base, k;
        reg [7:0] actual;
        begin
            base = (byte_address / 8) * 8;
            for (k = 0; k < 8; k = k + 1) begin
                actual = memory_model.mem[base/128][(base%128)/8][k*8 +: 8];
                if (actual !== expected[base+k]) begin
                    $display("byte %03h expected=%02h actual=%02h",
                             base+k, expected[base+k], actual);
                    fail("model byte or neighboring byte mismatch");
                end
                checks = checks + 1;
            end
        end
    endtask

    task check_all_memory;
        integer p;
        begin
            for (p = 0; p < 2048; p = p + 8) check_word(p);
        end
    endtask

    task transfer;
        input do_write;
        input [10:0] byte_address;
        input [7:0] byte_data;
        integer timeout, completion_start, commit_start, wr_start;
        begin
            @(negedge clk);
            if (busy !== 0 || ready !== 0) fail("transfer started before idle");
            completion_start = host_completions;
            commit_start = model_commits;
            wr_start = write_commands;
            req = 1;
            write = do_write;
            addr = byte_address;
            wdata = byte_data;
            timeout = 0;
            while (ready !== 1'b1) begin
                @(negedge clk);
                timeout = timeout + 1;
                if (timeout > 3000) fail("byte request timeout");
            end
            if (error !== 0) fail("unexpected error response");
            if (do_write) begin
                expected[byte_address] = byte_data;
                if (model_commits != commit_start+1 || write_commands != wr_start+1)
                    fail("write must commit exactly once before ready");
                check_word(byte_address);
            end else begin
                if (rdata !== expected[byte_address]) begin
                    $display("read %03h expected=%02h actual=%02h",
                             byte_address, expected[byte_address], rdata);
                    fail("read data mismatch");
                end
                if (model_commits != commit_start || write_commands != wr_start)
                    fail("read modified memory");
            end
            @(posedge clk);
            @(negedge clk);
            req = 0;
            if (host_completions != completion_start+1 || ready !== 0)
                fail("host completion must occur exactly once");
            checks = checks + 1;
        end
    endtask

    task cancel_before_write;
        integer start_wr, start_done;
        begin
            start_wr = write_commands;
            start_done = host_completions;
            @(negedge clk);
            req = 1;
            write = 1;
            addr = 11'h245;
            wdata = expected[11'h245] ^ 8'hff;
            // A write first reads its complete eight-byte group. Reset here
            // must drain that read and cancel the not-yet-issued write.
            wait (opcode == 5'b01101);
            @(posedge ck_t);
            @(negedge clk);
            rst_n = 0;
            req = 0;
            repeat (3) @(negedge clk);
            if (initialized !== 0) fail("reset did not invalidate initialization");
            rst_n = 1;
            wait_initialized;
            if (write_commands != start_wr || host_completions != start_done)
                fail("reset-before-WR was not cancelled");
            check_all_memory;
            checks = checks + 1;
        end
    endtask

    task reset_during_write;
        input integer hold_cycles;
        input [10:0] byte_address;
        integer start_done, start_commit;
        reg [7:0] new_value;
        begin
            start_done = host_completions;
            start_commit = model_commits;
            new_value = expected[byte_address] ^ 8'hc3;
            @(negedge clk);
            req = 1;
            write = 1;
            addr = byte_address;
            wdata = new_value;
            wait (opcode == 5'b01100);
            @(posedge ck_t);
            // Wait until two even lanes have really reached the model.
            repeat (2) @(posedge dqs_c);
            @(negedge clk);
            rst_n = 0;
            req = 0;
            repeat (hold_cycles) @(negedge clk);
            if (ready !== 0 || initialized !== 0)
                fail("reset must suppress completion/initialized");
            rst_n = 1;
            wait_initialized;
            expected[byte_address] = new_value;
            if (host_completions != start_done || model_commits != start_commit+1)
                fail("issued write must drain once without a host completion");
            check_all_memory;
            transfer(0, byte_address, 0);
            checks = checks + 1;
        end
    endtask

    initial begin
        // A global bound also covers waits for malformed/missing bus events.
        #20000000;
        fail("global testbench timeout");
    end

    initial begin
        if (T_RCD_CYCLES < 1 || T_RCD_CYCLES > 65535 ||
            (CL_CYCLES != 9 && CL_CYCLES != 10) ||
            (CWL_CYCLES != 10 && CWL_CYCLES != 11))
            fail("unsupported model timing parameters");
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("dram_controller.vcd");
            $dumpvars(0);
        end

        for (index = 0; index < 2048; index = index + 1)
            expected[index] = (index*37) ^ (index >> 3) ^ (index >> 8) ^ 8'h5a;
        for (row = 0; row < 16; row = row + 1)
            for (col = 0; col < 16; col = col + 1)
                for (lane = 0; lane < 8; lane = lane + 1)
                    memory_model.mem[row][col][lane*8 +: 8] =
                        expected[row*128+col*8+lane];

        repeat (4) @(negedge clk);
        rst_n = 1;
        wait_initialized;
        check_all_memory;

        transfer(1, 11'h000, 8'd10);
        transfer(0, 11'h000, 0);
        $display("DRAM_CONTROLLER_DEMO_PASS: address 0 write 10/read 10");
        transfer(1, 11'h7ff, 8'he7);
        transfer(0, 11'h000, 0);
        transfer(0, 11'h7ff, 0);
        for (index = 0; index < 8; index = index + 1) begin
            transfer(1, 11'h120+index, 8'h90+index);
            transfer(0, 11'h120+index, 0);
        end

        // Every local byte address is written, including every row/column
        // boundary. After EVERY byte write all eight actual model lanes are
        // checked, then all 2048 bytes are read through the controller.
        for (index = 0; index < 2048; index = index + 1) begin
            value = (index*73) ^ (index >> 3) ^ (index >> 8) ^ 8'ha7;
            transfer(1, index, value);
        end
        for (index = 0; index < 2048; index = index + 1)
            transfer(0, index, 0);
        $display("DRAM_CONTROLLER_ADDRESS_PASS: 2048 writes, 2048 reads, neighbor preservation");

        // Continuous req across two completions tests back-to-back requests.
        @(negedge clk);
        req = 1;
        write = 0;
        addr = 11'h07f;
        before_completions = host_completions;
        wait (ready === 1'b1);
        @(negedge clk);
        if (rdata !== expected[11'h07f]) fail("continuous req first read");
        @(posedge clk);
        @(negedge clk);
        addr = 11'h080;
        wait (ready === 1'b1);
        @(negedge clk);
        if (rdata !== expected[11'h080]) fail("continuous req second read");
        @(posedge clk);
        @(negedge clk);
        req = 0;
        if (host_completions != before_completions+2)
            fail("continuous req completion count");
        checks = checks + 2;

        // Idle reset must not clear any memory contents.
        @(negedge clk);
        rst_n = 0;
        repeat (4) @(negedge clk);
        if (ready !== 0 || rdata !== 0) fail("idle reset response state");
        rst_n = 1;
        wait_initialized;
        check_all_memory;
        cancel_before_write;
        reset_during_write(3, 11'h3fd);
        reset_during_write(200, 11'h782);
        if (write_commands != model_commits) fail("command/commit count mismatch");
        $display("DRAM_CONTROLLER_RESET_PASS: idle retention, read cancel, write drain (short/held reset)");
        $display("DRAM_CONTROLLER_PASS: CL=%0d CWL=%0d tRCD=%0d checks=%0d completions=%0d RD=%0d WR=%0d commits=%0d",
                 CL_CYCLES, CWL_CYCLES, T_RCD_CYCLES, checks,
                 host_completions, read_commands, write_commands, model_commits);
        $finish;
    end
endmodule

module tb_dram_controller_alt;
    tb_dram_controller #(
        .T_RCD_CYCLES(12), .CL_CYCLES(10), .CWL_CYCLES(11)
    ) test();
endmodule
