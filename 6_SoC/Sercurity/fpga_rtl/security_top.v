`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: security_top
// Target Device: CORE-5300 (Xilinx Zynq-7000 XC7Z010CLG400-1, PL Clock 50MHz U18)
// Description: Top-level Smart Security System in Verilog RTL (Mode-Switch Removed):
//              - Always-On Ultrasonic Intrusion Monitoring (50ms cycle, 5-sample MA)
//              - 24-Hour Digital Clock (HH:MM) on 4-Digit 7-Segment Display
//              - Dynamic Threshold (10~85cm) via Slide Switches SW[3:0]
//              - Latched Composite Alarm (LED[3:0], Buzzer, DC Motor DRV8848 PWM)
//              - Local Disarm via 1x4 Capacitive Touch Keypad (TTP224: 1->2->3->4)
//                with 20ms Hardware Debouncing & Wrong-Key PW:ERROR Reporting
//              - Remote Monitoring & "stop" Disarm via 9600bps UART Frame Protocol
//                with 1-Byte XOR Checksum (CRC8) & E:CRC Error Reporting
//////////////////////////////////////////////////////////////////////////////////

module security_top #(
    parameter integer CLKS_PER_US         = 50,
    parameter integer CLKS_PER_2MS        = 100_000,
    parameter integer CLKS_PER_50MS       = 2_500_000,
    parameter integer CLKS_PER_1S         = 50_000_000,
    parameter integer DEBOUNCE_CYCLES     = 1_000_000, // 20ms @ 50MHz (NFR-04)
    parameter integer SEC_PER_MIN         = 6,         // 6s per min demo clock (or 60)
    parameter integer CLKS_PER_BIT        = 5208,      // 50MHz / 9600bps
    parameter integer BLINK_TICKS_50MS    = 5,         // 250ms LED/Buzzer blink
    parameter integer REARM_TICKS_50MS    = 40,        // 2s post-disarm grace period
    parameter integer HOLD_RST_TICKS_50MS = 40         // 2s simultaneous PB1+PB2 hold for system reset
)(
    input  wire       clk,          // PL 50MHz System Clock (U18)
    input  wire [1:0] pb_key,       // PL Push Buttons: pb_key[0]=PB1(V15), pb_key[1]=PB2(W15)
    input  wire [3:0] sw,           // Slide Switches SW[3:0] (W14, Y14, T16, U17) -> Threshold
    input  wire [3:0] touch_key,    // 1x4 Touch Keypad TTP224 (L15, K16, J16, M17) -> Password
    input  wire       sonar_echo,   // HC-SR04 Echo (H20)
    output wire       sonar_trig,   // HC-SR04 Trig (J20)
    output wire [3:0] fnd_digit,    // 7-Segment Digit[3:0] (U12, T12, T10, T11) Active High
    output wire [7:0] fnd_seg,      // 7-Segment Seg[7:0](dp,g..a) (Y16..V13) Active Low
    output wire [3:0] led,          // PL LED[3:0] (P15, P16, N20, P20) Active High
    output wire       buzzer,       // Buzzer (L19) Active High
    output wire       motor_in1,    // DRV8848 Motor IN1 (K14)
    output wire       motor_in2,    // DRV8848 Motor IN2 / PWM (J14)
    output wire       motor_nsleep, // DRV8848 Motor nSleep (L14)
    input  wire       uart_rx,      // UART RX (from Zynq PS UART bridge or GPIO)
    output wire       uart_tx,      // UART TX (to Zynq PS UART bridge or GPIO)
    output wire       lcd_rs,       // 16x2 Text LCD Register Select (U20)
    output wire       lcd_e,        // 16x2 Text LCD Enable Strobe (V20)
    output wire [7:0] lcd_data      // 16x2 Text LCD Data DB7..DB0 (W18..W20)
);

    // 0. Power-On Reset (POR) generator (holds por_rst=1 for first 15 clocks after FPGA config)
    reg [3:0] por_cnt = 4'd0;
    wire      por_rst = (por_cnt != 4'd15);

    always @(posedge clk) begin
        if (por_cnt != 4'd15)
            por_cnt <= por_cnt + 4'd1;
    end

    // Internal timing ticks
    wire tick_1us;
    wire tick_2ms;
    wire tick_50ms;
    wire tick_1s;

    // 1. System Clock Divider (Step 2-A)
    clk_div #(
        .CLKS_PER_US   (CLKS_PER_US),
        .CLKS_PER_2MS  (CLKS_PER_2MS),
        .CLKS_PER_50MS (CLKS_PER_50MS),
        .CLKS_PER_1S   (CLKS_PER_1S)
    ) u_clk_div (
        .clk       (clk),
        .rst       (por_rst),
        .tick_1us  (tick_1us),
        .tick_2ms  (tick_2ms),
        .tick_50ms (tick_50ms),
        .tick_1s   (tick_1s)
    );

    // 2-A. 20ms Debouncers & Rising-Edge Detectors for PL Push Buttons PB1(V15), PB2(W15)
    wire [1:0] pb_clean;
    wire [1:0] pb_pulse;

    genvar p;
    generate
        for (p = 0; p < 2; p = p + 1) begin : gen_pb_debounce
            debounce_edge #(
                .DEBOUNCE_CYCLES (DEBOUNCE_CYCLES)
            ) u_deb_pb (
                .clk        (clk),
                .rst        (por_rst),
                .noisy_in   (pb_key[p]),
                .clean_out  (pb_clean[p]),
                .rise_pulse (pb_pulse[p])
            );
        end
    endgenerate

    // Simultaneous PB1 + PB2 2-second hold reset (NFR-03: prevents single-button reset!)
    reg [7:0] dual_hold_cnt = 8'd0;
    reg       dual_pb_rst   = 1'b0;

    always @(posedge clk) begin
        if (por_rst) begin
            dual_hold_cnt <= 8'd0;
            dual_pb_rst   <= 1'b0;
        end else if (pb_clean == 2'b11) begin
            if (tick_50ms) begin
                if (dual_hold_cnt >= HOLD_RST_TICKS_50MS - 1) begin
                    dual_pb_rst <= 1'b1;
                end else begin
                    dual_hold_cnt <= dual_hold_cnt + 8'd1;
                end
            end
        end else begin
            dual_hold_cnt <= 8'd0;
            dual_pb_rst   <= 1'b0;
        end
    end

    wire sys_rst = por_rst | dual_pb_rst;

    // 2-B. 20ms Debouncers & Rising-Edge Detectors for 1x4 Touch Keypad (Step 2-B, NFR-04)
    wire [3:0] key_clean;
    wire [3:0] key_pulse;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_key_debounce
            debounce_edge #(
                .DEBOUNCE_CYCLES (DEBOUNCE_CYCLES)
            ) u_deb_key (
                .clk        (clk),
                .rst        (sys_rst),
                .noisy_in   (touch_key[i]),
                .clean_out  (key_clean[i]),
                .rise_pulse (key_pulse[i])
            );
        end
    endgenerate

    // 3. Ultrasonic Sensor Controller with 50ms Period & 5-Sample Moving Average (Step 3, F-02, NFR-01, NFR-05)
    wire [15:0] distance_cm;
    wire [15:0] raw_dist_cm;
    wire        dist_valid;
    wire        err_sonar;
    wire        err_range;

    ultrasonic_ctrl u_ultrasonic (
        .clk         (clk),
        .rst         (sys_rst),
        .tick_1us    (tick_1us),
        .tick_50ms   (tick_50ms),
        .sonar_echo  (sonar_echo),
        .sonar_trig  (sonar_trig),
        .distance_cm (distance_cm),
        .raw_dist_cm (raw_dist_cm),
        .dist_valid  (dist_valid),
        .err_sonar   (err_sonar),
        .err_range   (err_range)
    );

    // 4. 24-Hour Digital Clock & 4-Digit 7-Segment Dynamic Controller (Displays Distance: e.g. 12.00)
    wire [4:0] hour;
    wire [5:0] minute;

    clock_fnd_ctrl #(
        .SEC_PER_MIN (SEC_PER_MIN)
    ) u_clock_fnd (
        .clk         (clk),
        .rst         (sys_rst),
        .tick_2ms    (tick_2ms),
        .tick_1s     (tick_1s),
        .distance_cm (distance_cm),
        .hour        (hour),
        .minute      (minute),
        .fnd_digit   (fnd_digit),
        .fnd_seg     (fnd_seg)
    );

    // 5. Security FSM & Composite Alarm Controller (Step 5, F-02, F-03, F-05)
    wire [15:0] threshold_cm;
    wire        alert_flag;
    wire [1:0]  pw_step;
    wire        ev_pw_step1;
    wire        ev_pw_step2;
    wire        ev_pw_step3;
    wire        ev_pw_ok_nrm;
    wire        ev_pw_ok_pc;
    wire        ev_pw_error;
    wire        ev_alert_trigger;
    wire [15:0] sensed_dist_cm;
    wire        disarm_hold;
    wire        cmd_stop_pulse;
    wire        crc_err_pulse;

    security_fsm #(
        .BLINK_TICKS_50MS (BLINK_TICKS_50MS),
        .REARM_TICKS_50MS (REARM_TICKS_50MS)
    ) u_security_fsm (
        .clk              (clk),
        .rst              (sys_rst),
        .tick_1us         (tick_1us),
        .tick_50ms        (tick_50ms),
        .sw               (sw),
        .pb_pulse         (pb_pulse),
        .key_pulse        (key_pulse),
        .distance_cm      (distance_cm),
        .dist_valid       (dist_valid),
        .cmd_stop_pulse   (cmd_stop_pulse),
        .threshold_cm     (threshold_cm),
        .alert_flag       (alert_flag),
        .pw_step          (pw_step),
        .ev_pw_step1      (ev_pw_step1),
        .ev_pw_step2      (ev_pw_step2),
        .ev_pw_step3      (ev_pw_step3),
        .ev_pw_ok_nrm     (ev_pw_ok_nrm),
        .ev_pw_ok_pc      (ev_pw_ok_pc),
        .ev_pw_error      (ev_pw_error),
        .ev_alert_trigger (ev_alert_trigger),
        .sensed_dist_cm   (sensed_dist_cm),
        .disarm_hold      (disarm_hold),
        .led              (led),
        .buzzer           (buzzer),
        .motor_in1        (motor_in1),
        .motor_in2        (motor_in2),
        .motor_nsleep     (motor_nsleep)
    );

    // 6. UART Frame Transceiver with CRC8 Checksum & "stop" Command Parser (Step 6, F-04, NFR-02)
    uart_frame_ctrl #(
        .CLKS_PER_BIT (CLKS_PER_BIT)
    ) u_uart_frame (
        .clk              (clk),
        .rst              (sys_rst),
        .tick_1s          (tick_1s),
        .uart_rx          (uart_rx),
        .uart_tx          (uart_tx),
        .distance_cm      (distance_cm),
        .threshold_cm     (threshold_cm),
        .ev_pw_step1      (ev_pw_step1),
        .alert_flag       (alert_flag),
        .ev_pw_step2      (ev_pw_step2),
        .ev_pw_step3      (ev_pw_step3),
        .ev_pw_ok_nrm     (ev_pw_ok_nrm),
        .ev_pw_ok_pc      (ev_pw_ok_pc),
        .ev_pw_error      (ev_pw_error),
        .ev_err_sonar     (err_sonar),
        .ev_err_range     (err_range),
        .ev_alert_trigger (ev_alert_trigger),
        .sensed_dist_cm   (sensed_dist_cm),
        .cmd_stop_pulse   (cmd_stop_pulse),
        .crc_err_pulse    (crc_err_pulse)
    );

    // 7. 16x2 Character Text LCD Controller (S6A0069 / HD44780)
    lcd_ctrl #(
        .SIMULATION (0)
    ) u_lcd_ctrl (
        .clk          (clk),
        .rst          (sys_rst),
        .guard_active (threshold_cm > 16'd0),
        .alert_flag   (alert_flag),
        .disarm_hold  (disarm_hold),
        .pw_step      (pw_step),
        .lcd_rs       (lcd_rs),
        .lcd_e        (lcd_e),
        .lcd_data     (lcd_data)
    );

endmodule
