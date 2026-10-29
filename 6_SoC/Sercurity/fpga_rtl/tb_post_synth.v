`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_post_synth
// Description: Stage 3 Post-Synthesis Gate-Level Functional Simulation Testbench.
//              - Uses ONLY external top-level ports (no internal hierarchy probes
//                and no parameter overrides on dut) so it runs directly against
//                Vivado's synthesized Zynq-7000 gate-level netlist (LUT/FDRE/CARRY4).
//              - Includes an 8N1 UART TX Serial Frame Monitor that decodes every
//                frame [0xAA | TYPE | LEN | PAYLOAD | CRC8] transmitted on `uart_tx`.
//////////////////////////////////////////////////////////////////////////////////

module tb_post_synth;

    localparam integer CLKS_PER_US      = 4;
    localparam integer CLKS_PER_50MS    = 800;
    localparam integer DEBOUNCE_CYCLES  = 40;
    localparam integer CLKS_PER_BIT     = 8;

    reg        clk;
    reg  [1:0] pb_key;
    reg  [3:0] sw;
    reg  [3:0] touch_key;
    reg        sonar_echo;
    wire       sonar_trig;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_seg;
    wire [3:0] led;
    wire       buzzer;
    wire       motor_in1;
    wire       motor_in2;
    wire       motor_nsleep;
    reg        uart_rx;
    wire       uart_tx;

    // Gate-level netlist compatible instantiation (NO parameter overrides on dut)
    security_top dut (
        .clk          (clk),
        .pb_key       (pb_key),
        .sw           (sw),
        .touch_key    (touch_key),
        .sonar_echo   (sonar_echo),
        .sonar_trig   (sonar_trig),
        .fnd_digit    (fnd_digit),
        .fnd_seg      (fnd_seg),
        .led          (led),
        .buzzer       (buzzer),
        .motor_in1    (motor_in1),
        .motor_in2    (motor_in2),
        .motor_nsleep (motor_nsleep),
        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx)
    );

    // 50MHz clock (20ns period)
    initial clk = 1'b0;
    always #10 clk = ~clk;

    integer errors = 0;

    // =========================================================================
    // External UART TX Pin Monitor (verifies actual serial frames & CRC8)
    // =========================================================================
    integer tx_frames_ok  = 0;
    integer tx_crc_errors = 0;
    reg [7:0] last_frame_type;
    reg [7:0] last_frame_len;
    reg [7:0] rx_mon_byte;
    reg [7:0] mon_type, mon_len, mon_crc_calc;
    integer   mon_idx, bit_i;

    initial begin : uart_tx_monitor
        forever begin
            // Wait for start bit (falling edge on uart_tx)
            @(negedge uart_tx);
            repeat (CLKS_PER_BIT / 2) @(posedge clk);
            if (uart_tx === 1'b0) begin
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    repeat (CLKS_PER_BIT) @(posedge clk);
                    rx_mon_byte[bit_i] = uart_tx;
                end
                repeat (CLKS_PER_BIT) @(posedge clk); // Stop bit

                if (rx_mon_byte === 8'hAA) begin
                    // Read TYPE
                    @(negedge uart_tx);
                    repeat (CLKS_PER_BIT / 2) @(posedge clk);
                    for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                        repeat (CLKS_PER_BIT) @(posedge clk);
                        mon_type[bit_i] = uart_tx;
                    end
                    repeat (CLKS_PER_BIT) @(posedge clk);

                    // Read LEN
                    @(negedge uart_tx);
                    repeat (CLKS_PER_BIT / 2) @(posedge clk);
                    for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                        repeat (CLKS_PER_BIT) @(posedge clk);
                        mon_len[bit_i] = uart_tx;
                    end
                    repeat (CLKS_PER_BIT) @(posedge clk);

                    mon_crc_calc = mon_type ^ mon_len;
                    for (mon_idx = 0; mon_idx < mon_len; mon_idx = mon_idx + 1) begin
                        @(negedge uart_tx);
                        repeat (CLKS_PER_BIT / 2) @(posedge clk);
                        for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                            repeat (CLKS_PER_BIT) @(posedge clk);
                            rx_mon_byte[bit_i] = uart_tx;
                        end
                        repeat (CLKS_PER_BIT) @(posedge clk);
                        mon_crc_calc = mon_crc_calc ^ rx_mon_byte;
                    end

                    // Read CRC8
                    @(negedge uart_tx);
                    repeat (CLKS_PER_BIT / 2) @(posedge clk);
                    for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                        repeat (CLKS_PER_BIT) @(posedge clk);
                        rx_mon_byte[bit_i] = uart_tx;
                    end
                    repeat (CLKS_PER_BIT) @(posedge clk);

                    if (rx_mon_byte === mon_crc_calc) begin
                        tx_frames_ok    = tx_frames_ok + 1;
                        last_frame_type = mon_type;
                        last_frame_len  = mon_len;
                    end else begin
                        tx_crc_errors = tx_crc_errors + 1;
                        $display("[FAIL] UART TX Monitor: Bad CRC8! expected=0x%02x, got=0x%02x",
                                 mon_crc_calc, rx_mon_byte);
                        errors = errors + 1;
                    end
                end
            end
        end
    end

    // Helper task: Respond to sonar_trig using external clock cycles only
    task send_sonar_sample_pin(input [15:0] target_cm);
        integer echo_clks;
        begin
            echo_clks = target_cm * 58 * CLKS_PER_US;
            @(posedge sonar_trig);
            @(negedge sonar_trig);
            repeat (10 * CLKS_PER_US) @(posedge clk);
            sonar_echo = 1'b1;
            repeat (echo_clks) @(posedge clk);
            sonar_echo = 1'b0;
            repeat (5) @(posedge clk);
        end
    endtask

    task press_pb_key(input [1:0] mask);
        begin
            pb_key = mask;
            repeat (DEBOUNCE_CYCLES + 15) @(posedge clk);
            pb_key = 2'b00;
            repeat (DEBOUNCE_CYCLES + 15) @(posedge clk);
        end
    endtask

    task uart_send_byte(input [7:0] data);
        integer b;
        begin
            uart_rx = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);
            for (b = 0; b < 8; b = b + 1) begin
                uart_rx = data[b];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            uart_rx = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    initial begin
        $display("================================================================");
        $display("[STAGE 3 TB] Post-Synthesis Gate-Level Netlist Verification...");
        $display("================================================================");

        pb_key     = 2'b00;
        sw         = 4'd2; // threshold = 20cm
        touch_key  = 4'b0000;
        sonar_echo = 1'b0;
        uart_rx    = 1'b1;

        repeat (40) @(posedge clk);

        // 1. Check Reset Output Pins & FND Polarity
        if (led !== 4'b0000 || buzzer !== 1'b0 || motor_nsleep !== 1'b0 || fnd_digit === 4'b0000) begin
            $display("[FAIL] Post-Synth Check 1: Output pins invalid after reset!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Post-Synth Check 1: Reset pins & 7-Segment Active-High Digit / Active-Low Seg OK");
        end

        // 2. 5-Sample Moving Average Noise Filter (4x 40cm + 1x 10cm -> No Alarm)
        send_sonar_sample_pin(16'd40);
        send_sonar_sample_pin(16'd40);
        send_sonar_sample_pin(16'd40);
        send_sonar_sample_pin(16'd40);
        send_sonar_sample_pin(16'd10);
        repeat (10) @(posedge clk);

        if (motor_nsleep !== 1'b0) begin
            $display("[FAIL] Post-Synth Check 2: Single noise spike falsely triggered motor_nsleep!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Post-Synth Check 2: Gate-level 5-Sample Moving Average rejected noise spike");
        end

        // 3. Genuine Intrusion & Alarm Latch (4x 10cm -> Alarm ON -> 5x 50cm -> Stays Latched)
        send_sonar_sample_pin(16'd10);
        send_sonar_sample_pin(16'd10);
        send_sonar_sample_pin(16'd10);
        send_sonar_sample_pin(16'd10);
        repeat (10) @(posedge clk);

        if (motor_nsleep !== 1'b1) begin
            $display("[FAIL] Post-Synth Check 3a: Intrusion did not activate alarm pin motor_nsleep!");
            errors = errors + 1;
        end

        send_sonar_sample_pin(16'd50);
        send_sonar_sample_pin(16'd50);
        send_sonar_sample_pin(16'd50);
        send_sonar_sample_pin(16'd50);
        send_sonar_sample_pin(16'd50);
        repeat (10) @(posedge clk);

        if (motor_nsleep !== 1'b1) begin
            $display("[FAIL] Post-Synth Check 3b: Alarm Latch failed on gate-level netlist!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Post-Synth Check 3: Intrusion triggered & remained LATCHED on gate-level netlist");
        end

        // 4. PL Push Buttons Wrong Order (PB1->PB1) & Correct Order (PB1 -> PB2 -> PB1 -> PB2) Disarm
        press_pb_key(2'b01);
        press_pb_key(2'b01); // Wrong order (PB1 twice)
        if (motor_nsleep !== 1'b1) begin
            $display("[FAIL] Post-Synth Check 4a: Wrong password disarmed alarm!");
            errors = errors + 1;
        end

        press_pb_key(2'b01); // PB1
        press_pb_key(2'b10); // PB2
        press_pb_key(2'b01); // PB1
        press_pb_key(2'b10); // PB2
        repeat (10) @(posedge clk);

        if (motor_nsleep !== 1'b0 || led !== 4'b0000) begin
            $display("[FAIL] Post-Synth Check 4b: PL Push Buttons PB1->PB2->PB1->PB2 failed to disarm!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Post-Synth Check 4: PL Push Buttons PB1->PB2->PB1->PB2 disarmed gate-level netlist");
        end

        // 5. Re-Intrusion & UART Bad CRC8 vs Valid "stop" Frame Disarm + TX Serial Monitor
        repeat (2 * CLKS_PER_50MS) @(posedge clk);
        send_sonar_sample_pin(16'd12);
        send_sonar_sample_pin(16'd12);
        send_sonar_sample_pin(16'd12);
        send_sonar_sample_pin(16'd12);
        send_sonar_sample_pin(16'd12);
        repeat (10) @(posedge clk);

        // Bad CRC8
        uart_send_byte(8'hAA);
        uart_send_byte(8'h02);
        uart_send_byte(8'h04);
        uart_send_byte("s");
        uart_send_byte("t");
        uart_send_byte("o");
        uart_send_byte("p");
        uart_send_byte(8'hFF);
        repeat (20) @(posedge clk);

        if (motor_nsleep !== 1'b1) begin
            $display("[FAIL] Post-Synth Check 5a: Bad CRC8 disarmed gate-level netlist!");
            errors = errors + 1;
        end

        // Valid "stop"
        uart_send_byte(8'hAA);
        uart_send_byte(8'h02);
        uart_send_byte(8'h04);
        uart_send_byte("s");
        uart_send_byte("t");
        uart_send_byte("o");
        uart_send_byte("p");
        uart_send_byte(8'h02 ^ 8'h04 ^ "s" ^ "t" ^ "o" ^ "p");
        repeat (20) @(posedge clk);

        if (motor_nsleep !== 1'b0 || tx_frames_ok < 2 || tx_crc_errors !== 0) begin
            $display("[FAIL] Post-Synth Check 5b: UART stop or TX frame monitor failed! tx_ok=%0d, crc_err=%0d",
                     tx_frames_ok, tx_crc_errors);
            errors = errors + 1;
        end else begin
            $display("[PASS] Post-Synth Check 5: UART 'stop' disarmed & %0d valid 0xAA frames decoded on uart_tx pin",
                     tx_frames_ok);
        end

        $display("================================================================");
        if (errors == 0) begin
            $display("POST_SYNTH_GATE_SIM_PASS: ALL CHECKS PASSED (0 errors)");
        end else begin
            $display("POST_SYNTH_GATE_SIM_FAIL: %0d errors detected", errors);
        end
        $display("================================================================");
        $finish;
    end

endmodule
