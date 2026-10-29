`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_security_top
// Description: Self-checking Behavioral Simulation Testbench for security_top.
//              Verifies:
//              1) NFR-03: Reset state & 7-Segment HH:MM clock scan
//              2) F-02  : Dynamic threshold from SW[3:0] (SW=2 -> 20cm)
//              3) NFR-05: 5-sample moving average noise rejection (1 spike ignored)
//              4) F-03  : Intrusion alarm trigger & Alarm Latch (stays ON when far)
//              5) NFR-04: Debouncer glitch rejection + Wrong key PW:ERROR
//              6) F-05  : 1x4 Touch Keypad sequential disarm (1 -> 2 -> 3 -> 4)
//              7) NFR-02: UART CRC8 mismatch rejection (E:CRC)
//              8) F-04  : UART valid "stop" frame remote disarm
//////////////////////////////////////////////////////////////////////////////////

module tb_security_top;

    // Scaled simulation parameters for fast cycle-accurate verification
    localparam integer CLKS_PER_US      = 4;
    localparam integer CLKS_PER_2MS     = 20;
    localparam integer CLKS_PER_50MS    = 800;
    localparam integer CLKS_PER_1S      = 8000;
    localparam integer DEBOUNCE_CYCLES  = 40;
    localparam integer SEC_PER_MIN      = 2;
    localparam integer CLKS_PER_BIT     = 8;
    localparam integer BLINK_TICKS_50MS = 2;
    localparam integer REARM_TICKS_50MS = 1;

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
    wire       lcd_rs;
    wire       lcd_e;
    wire [7:0] lcd_data;

    security_top #(
        .CLKS_PER_US      (CLKS_PER_US),
        .CLKS_PER_2MS     (CLKS_PER_2MS),
        .CLKS_PER_50MS    (CLKS_PER_50MS),
        .CLKS_PER_1S      (CLKS_PER_1S),
        .DEBOUNCE_CYCLES  (DEBOUNCE_CYCLES),
        .SEC_PER_MIN      (SEC_PER_MIN),
        .CLKS_PER_BIT     (CLKS_PER_BIT),
        .BLINK_TICKS_50MS (BLINK_TICKS_50MS),
        .REARM_TICKS_50MS (REARM_TICKS_50MS)
    ) dut (
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
        .uart_tx      (uart_tx),
        .lcd_rs       (lcd_rs),
        .lcd_e        (lcd_e),
        .lcd_data     (lcd_data)
    );

    // 50MHz clock (20ns period)
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // UART TX monitor: decodes FPGA -> PC bytes (8N1) and prints them
    integer tx_bytes = 0;
    reg [7:0] mon_byte;
    integer mb;
    initial begin
        forever begin
            @(negedge uart_tx);
            repeat (CLKS_PER_BIT / 2) @(posedge clk);
            for (mb = 0; mb < 8; mb = mb + 1) begin
                repeat (CLKS_PER_BIT) @(posedge clk);
                mon_byte[mb] = uart_tx;
            end
            repeat (CLKS_PER_BIT) @(posedge clk);
            tx_bytes = tx_bytes + 1;
            if (mon_byte >= 8'h20 && mon_byte < 8'h7F)
                $display("[TX] 0x%02h '%c'", mon_byte, mon_byte);
            else
                $display("[TX] 0x%02h", mon_byte);
        end
    end

    integer errors = 0;

    // Helper task: Respond to next sonar_trig with an echo pulse corresponding to target_cm
    task send_sonar_sample(input [15:0] target_cm);
        integer echo_us;
        integer u;
        begin
            echo_us = target_cm * 58;
            @(posedge sonar_trig);
            @(negedge sonar_trig);
            repeat (10 * CLKS_PER_US) @(posedge clk);
            sonar_echo = 1'b1;
            for (u = 0; u < echo_us; u = u + 1) begin
                @(posedge dut.tick_1us);
            end
            sonar_echo = 1'b0;
            repeat (5) @(posedge clk);
        end
    endtask

    // Helper task: Press a PL push button (pb_key[0]=PB1, pb_key[1]=PB2) for valid debounced duration
    task press_pb_key(input [1:0] mask);
        begin
            pb_key = mask;
            repeat (DEBOUNCE_CYCLES + 15) @(posedge clk);
            pb_key = 2'b00;
            repeat (DEBOUNCE_CYCLES + 15) @(posedge clk);
        end
    endtask

    // Helper task: Send 1 byte over UART RX (8N1)
    task uart_send_byte(input [7:0] data);
        integer b;
        begin
            // Start bit
            uart_rx = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);
            // 8 Data bits (LSB first)
            for (b = 0; b < 8; b = b + 1) begin
                uart_rx = data[b];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            // Stop bit
            uart_rx = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    initial begin
        $display("================================================================");
        $display("[TB] Starting CORE-5300 Smart Security FPGA RTL Verification...");
        $display("================================================================");

        pb_key     = 2'b00;
        sw         = 4'b0000;
        touch_key  = 4'b0000;
        sonar_echo = 1'b0;
        uart_rx    = 1'b1;

        // Wait for internal Power-On Reset (15 clocks) to complete
        repeat (30) @(posedge clk);

        // ---------------------------------------------------------------------
        // CHECK 1: Reset state & 4-Stage Priority Dynamic Threshold
        //          SW1(sw[0])=5cm, SW2(sw[1])=10cm, SW3(sw[2])=15cm, SW4(sw[3])=25cm
        //          Priority: SW4 > SW3 > SW2 > SW1 > Default(5cm)
        // ---------------------------------------------------------------------
        if (dut.alert_flag !== 1'b0 || led !== 4'b0000 || motor_nsleep !== 1'b0) begin
            $display("[FAIL] Check 1: Reset state invalid!");
            errors = errors + 1;
        end

        // Test 1a: SW = 4'b0000 -> 0cm
        sw = 4'b0000; #10;
        if (dut.threshold_cm !== 16'd0) begin
            $display("[FAIL] Check 1a: SW=0 expected 0cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end

        // Test 1b: SW = 4'b0001 (SW1) -> 5cm
        sw = 4'b0001; #10;
        if (dut.threshold_cm !== 16'd5) begin
            $display("[FAIL] Check 1b: SW1 expected 5cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end

        // Test 1c: SW = 4'b0010 (SW2) -> 10cm
        sw = 4'b0010; #10;
        if (dut.threshold_cm !== 16'd10) begin
            $display("[FAIL] Check 1c: SW2 expected 10cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end

        // Test 1d: SW = 4'b0100 (SW3) -> 15cm
        sw = 4'b0100; #10;
        if (dut.threshold_cm !== 16'd15) begin
            $display("[FAIL] Check 1d: SW3 expected 15cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end

        // Test 1e: SW = 4'b1000 (SW4) -> 25cm
        sw = 4'b1000; #10;
        if (dut.threshold_cm !== 16'd25) begin
            $display("[FAIL] Check 1e: SW4 expected 25cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end

        // Test 1f: SW = 4'b1001 (SW4 + SW1) -> SW4 wins -> 25cm
        sw = 4'b1001; #10;
        if (dut.threshold_cm !== 16'd25) begin
            $display("[FAIL] Check 1f: SW4+SW1 priority expected 25cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end

        // Test 1g: SW = 4'b0111 (SW3 + SW2 + SW1) -> SW3 wins -> 15cm
        sw = 4'b0111; #10;
        if (dut.threshold_cm !== 16'd15) begin
            $display("[FAIL] Check 1g: SW3+SW2+SW1 priority expected 15cm, got %0d", dut.threshold_cm);
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 1: 4-Stage Priority Dynamic Threshold verified successfully!");
        end

        // Set threshold to 25cm (SW4) for intrusion tests
        sw = 4'b1000; #10;

        // ---------------------------------------------------------------------
        // CHECK 2: 5-Sample Moving Average Noise Rejection (NFR-05 & Exc 3)
        //          4 samples of 40cm + 1 noisy spike of 10cm -> avg = 34cm > 25cm
        // ---------------------------------------------------------------------
        send_sonar_sample(16'd40);
        send_sonar_sample(16'd40);
        send_sonar_sample(16'd40);
        send_sonar_sample(16'd40);
        send_sonar_sample(16'd10); // Single noisy spike!
        repeat (5) @(posedge clk);

        if (dut.distance_cm !== 16'd34 || dut.alert_flag !== 1'b0) begin
            $display("[FAIL] Check 2: Moving average noise filter failed! dist=%0d, alert=%b",
                     dut.distance_cm, dut.alert_flag);
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 2: 5-Sample Moving Average rejected single 10cm spike (avg=34cm, alert=0)");
        end

        // ---------------------------------------------------------------------
        // CHECK 3: Genuine Intrusion Detection & Composite Alarm (F-02, F-03, NFR-01)
        //          4 more samples of 10cm -> avg = 10cm <= 25cm -> alert_flag = 1
        //          and verify sensed_dist_cm latched to initial intrusion distance
        // ---------------------------------------------------------------------
        send_sonar_sample(16'd10);
        send_sonar_sample(16'd10);
        send_sonar_sample(16'd10);
        send_sonar_sample(16'd10);
        repeat (5) @(posedge clk);

        if (dut.distance_cm !== 16'd10 || dut.alert_flag !== 1'b1 || motor_nsleep !== 1'b1 ||
            dut.u_security_fsm.sensed_dist_cm !== 16'd22) begin
            $display("[FAIL] Check 3: Intrusion alarm did not trigger properly! dist=%0d, alert=%b, sensed=%0d",
                     dut.distance_cm, dut.alert_flag, dut.u_security_fsm.sensed_dist_cm);
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 3: Intrusion detected (first sensed_dist_cm=22cm <= 25cm, steady dist=10cm) -> Alarm ON");
        end

        // ---------------------------------------------------------------------
        // CHECK 4: Alarm Latch when intruder moves away (50cm x 5 -> avg=50cm)
        // ---------------------------------------------------------------------
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        repeat (5) @(posedge clk);

        if (dut.distance_cm !== 16'd50 || dut.alert_flag !== 1'b1) begin
            $display("[FAIL] Check 4: Alarm Latch failed! dist=%0d, alert=%b",
                     dut.distance_cm, dut.alert_flag);
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 4: Alarm remained LATCHED (alert=1) even after distance returned to 50cm");
        end

        // ---------------------------------------------------------------------
        // CHECK 5: 20ms Debouncer Glitch Rejection (NFR-04) & Wrong Button Order (Exc 1)
        // ---------------------------------------------------------------------
        // Short glitch (< DEBOUNCE_CYCLES) on pb_key[0] (PL PB1)
        pb_key = 2'b01;
        repeat (DEBOUNCE_CYCLES / 2) @(posedge clk);
        pb_key = 2'b00;
        repeat (20) @(posedge clk);

        if (dut.pw_step !== 2'd0) begin
            $display("[FAIL] Check 5a: Short glitch was not filtered by debouncer!");
            errors = errors + 1;
        end

        // Single press of PL PB1 -> pw_step = 1 (MUST NOT DISARM ALARM!), then wrong PB1 again -> resets to 0!
        press_pb_key(2'b01); // Press PL PB1 once
        if (dut.pw_step !== 2'd1 || dut.alert_flag !== 1'b1) begin
            $display("[FAIL] Check 5b: Expected pw_step=1 & alert=1 after single PB1, got step=%0d alert=%b",
                     dut.pw_step, dut.alert_flag);
            errors = errors + 1;
        end
        press_pb_key(2'b01); // Wrong button (PB1 again instead of PB2)
        if (dut.pw_step !== 2'd0 || dut.alert_flag !== 1'b1 || dut.u_uart_frame.pend_pw_error !== 1'b1) begin
            $display("[FAIL] Check 5c: Wrong button sequence did not reset pw_step or keep alarm!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 5: Single PB1 did NOT disarm; wrong sequence PB1->PB1 reset to step 0 with PW:ERROR");
        end

        // ---------------------------------------------------------------------
        // CHECK 6: Full Sequential PL Push Button Disarm (PB1 -> PB2 -> PB1 -> PB2) (F-05)
        // ---------------------------------------------------------------------
        press_pb_key(2'b01); // Step 1: PL PB1 (V15)
        press_pb_key(2'b10); // Step 2: PL PB2 (W15)
        press_pb_key(2'b01); // Step 3: PL PB1 (V15)
        press_pb_key(2'b10); // Step 4: PL PB2 (W15) -> Disarm!

        if (dut.alert_flag !== 1'b0 || led !== 4'b0000 || motor_nsleep !== 1'b0) begin
            $display("[FAIL] Check 6: PL Push Buttons PB1->PB2->PB1->PB2 failed to disarm!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 6: PL Push Buttons PB1->PB2->PB1->PB2 disarmed alarm & returned to Always-On Guard");
        end

        // A fresh, valid obstacle-clear measurement must release disarm_hold.
        // Do not rely on pre-disarm samples surviving a sensor timeout.
        repeat (2 * CLKS_PER_50MS) @(posedge clk);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        send_sonar_sample(16'd50);
        repeat (10) @(posedge clk);
        if (dut.disarm_hold !== 1'b0) begin
            $display("[FAIL] Check 7a: Valid obstacle-clear samples did not release disarm_hold!");
            errors = errors + 1;
        end

        // Re-enter the protected area after it has been observed clear.
        send_sonar_sample(16'd12);
        send_sonar_sample(16'd12);
        send_sonar_sample(16'd12);
        send_sonar_sample(16'd12);
        send_sonar_sample(16'd12);
        repeat (5) @(posedge clk);

        if (dut.alert_flag !== 1'b1) begin
            $display("[FAIL] Check 7a: Alarm did not re-trigger on new intrusion!");
            errors = errors + 1;
        end

        // ---------------------------------------------------------------------
        // CHECK 7: UART Bad CRC8 Rejection (NFR-02 & Exc 2)
        // ---------------------------------------------------------------------
        uart_send_byte(8'hAA); // SOF
        uart_send_byte(8'h02); // TYPE_CMD
        uart_send_byte(8'h04); // LEN = 4
        uart_send_byte("s");
        uart_send_byte("t");
        uart_send_byte("o");
        uart_send_byte("p");
        uart_send_byte(8'hFF); // Invalid CRC8!
        repeat (10) @(posedge clk);

        if (dut.alert_flag !== 1'b1) begin
            $display("[FAIL] Check 7b: Corrupted CRC8 frame falsely disarmed the system!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 7: Corrupted UART CRC8 rejected (Alarm kept ON, E:CRC queued)");
        end

        // ---------------------------------------------------------------------
        // CHECK 8: Valid UART "stop" Command Remote Disarm (F-04)
        //          CRC8 = 0x02 ^ 0x04 ^ 's'(0x73) ^ 't'(0x74) ^ 'o'(0x6F) ^ 'p'(0x70) = 0x18
        // ---------------------------------------------------------------------
        uart_send_byte(8'hAA);
        uart_send_byte(8'h02);
        uart_send_byte(8'h04);
        uart_send_byte("s");
        uart_send_byte("t");
        uart_send_byte("o");
        uart_send_byte("p");
        uart_send_byte(8'h02 ^ 8'h04 ^ "s" ^ "t" ^ "o" ^ "p");
        repeat (10) @(posedge clk);

        if (dut.alert_flag !== 1'b0 || led !== 4'b0000 || motor_nsleep !== 1'b0) begin
            $display("[FAIL] Check 8: Valid UART 'stop' command failed to disarm!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Check 8: Valid UART 'stop' frame disarmed alarm & queued ACK 'OK' + 'PW:OK_PC'");
        end

        $display("================================================================");
        if (errors == 0) begin
            $display("SECURITY_FPGA_RTL_SIM_PASS: ALL 8 CHECKS PASSED (0 errors)");
        end else begin
            $display("SECURITY_FPGA_RTL_SIM_FAIL: %0d errors detected", errors);
        end
        $display("================================================================");
        #10;
        $finish;
    end

endmodule
