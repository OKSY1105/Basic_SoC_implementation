`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: security_fsm
// Description: Always-On Smart Security Controller (Mode-switch removed):
//              - Dynamic threshold from Slide Switches SW[3:0]: 10 + SW*5 (cm)
//              - Intrusion detection (distance_cm <= threshold_cm) with Alarm Latch
//              - 1x4 Touch Keypad (TTP224) sequential password FSM (1->2->3->4)
//                with wrong-input PW:ERROR exception reporting
//              - PC UART "stop" remote disarm support
//              - Composite Alarm outputs: LED[3:0] blink, Buzzer, DRV8848 DC Motor PWM
//////////////////////////////////////////////////////////////////////////////////

module security_fsm #(
    parameter integer BLINK_TICKS_50MS = 5,  // 250ms LED/Buzzer toggle period
    parameter integer REARM_TICKS_50MS = 40  // 2s grace period after disarm
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_1us,
    input  wire        tick_50ms,
    input  wire [3:0]  sw,             // PL Slide Switches SW[3:0] (W14, Y14, T16, U17)
    input  wire [1:0]  pb_pulse,       // Debounced 1-clock pulses from PL PB1(V15), PB2(W15)
    input  wire [3:0]  key_pulse,      // Debounced 1-clock pulses from 1x4 Touch Keypad
    input  wire [15:0] distance_cm,    // 5-sample moving average distance (cm)
    input  wire        dist_valid,     // 1-clock pulse when distance_cm is updated
    input  wire        cmd_stop_pulse, // 1-clock pulse when valid UART CMD "stop" arrives
    output wire [15:0] threshold_cm,   // Dynamic threshold (10 ~ 85 cm)
    output reg         alert_flag,     // Latched alarm state (1 = ALARM ON)
    output reg  [1:0]  pw_step,        // Password FSM progress (0..3)
    output reg         ev_pw_step1,
    output reg         ev_pw_step2,
    output reg         ev_pw_step3,
    output reg         ev_pw_ok_nrm,
    output reg         ev_pw_ok_pc,
    output reg         ev_pw_error,
    output reg         ev_alert_trigger,
    output reg  [15:0] sensed_dist_cm,
    output reg         disarm_hold,
    output reg  [3:0]  led,            // PL LED 0~3 (P15, P16, N20, P20) Active High
    output reg         buzzer,         // Buzzer (L19) Active High
    output reg         motor_in1,      // DRV8848 IN1 (K14)
    output reg         motor_in2,      // DRV8848 IN2 / PWM (J14)
    output reg         motor_nsleep    // DRV8848 nSleep (L14, Active High enable)
);

    // 4-Stage Priority-based threshold selection:
    // SW4 (sw[3]) -> 25cm (Highest priority)
    // SW3 (sw[2]) -> 15cm
    // SW2 (sw[1]) -> 10cm
    // SW1 (sw[0]) -> 5cm
    // All OFF     -> 0cm (Detection standby / 0cm)
    assign threshold_cm = sw[3] ? 16'd25 :
                          sw[2] ? 16'd15 :
                          sw[1] ? 16'd10 :
                          sw[0] ? 16'd5  : 16'd0;

    reg [7:0] blink_cnt;
    reg       blink_phase;
    reg [7:0] rearm_cnt;
    reg [9:0] pwm_us_cnt;

    // 1kHz PWM counter (1000 us period, 75% duty cycle) for DC Motor DRV8848
    always @(posedge clk) begin
        if (rst) begin
            pwm_us_cnt <= 10'd0;
        end else if (tick_1us) begin
            if (pwm_us_cnt >= 10'd999)
                pwm_us_cnt <= 10'd0;
            else
                pwm_us_cnt <= pwm_us_cnt + 10'd1;
        end
    end

    wire any_pb_or_key = (|pb_pulse) || (|key_pulse);
    wire step1_match   = (pb_pulse == 2'b01 && key_pulse == 4'b0000) || (pb_pulse == 2'b00 && key_pulse == 4'b0001); // PL PB1 or Touch 1
    wire step2_match   = (pb_pulse == 2'b10 && key_pulse == 4'b0000) || (pb_pulse == 2'b00 && key_pulse == 4'b0010); // PL PB2 or Touch 2
    wire step3_match   = (pb_pulse == 2'b01 && key_pulse == 4'b0000) || (pb_pulse == 2'b00 && key_pulse == 4'b0100); // PL PB1 or Touch 3
    wire step4_match   = (pb_pulse == 2'b10 && key_pulse == 4'b0000) || (pb_pulse == 2'b00 && key_pulse == 4'b1000); // PL PB2 or Touch 4

    // Main Always-On Security & Password FSM
    always @(posedge clk) begin
        if (rst) begin
            alert_flag       <= 1'b0;
            pw_step          <= 2'd0;
            rearm_cnt        <= 8'd0;
            disarm_hold      <= 1'b0;
            ev_pw_step1      <= 1'b0;
            ev_pw_step2      <= 1'b0;
            ev_pw_step3      <= 1'b0;
            ev_pw_ok_nrm     <= 1'b0;
            ev_pw_ok_pc      <= 1'b0;
            ev_pw_error      <= 1'b0;
            ev_alert_trigger <= 1'b0;
            sensed_dist_cm   <= 16'd0;
        end else begin
            ev_pw_step1      <= 1'b0;
            ev_pw_step2      <= 1'b0;
            ev_pw_step3      <= 1'b0;
            ev_pw_ok_nrm     <= 1'b0;
            ev_pw_ok_pc      <= 1'b0;
            ev_pw_error      <= 1'b0;
            ev_alert_trigger <= 1'b0;

            // Post-disarm grace counter countdown
            if (tick_50ms && rearm_cnt > 8'd0) begin
                rearm_cnt <= rearm_cnt - 8'd1;
            end

            // 1. Remote PC UART "stop" command has highest priority for disarming
            if (cmd_stop_pulse) begin
                alert_flag  <= 1'b0;
                pw_step     <= 2'd0;
                disarm_hold <= 1'b1; // Hold disarmed state until obstacle clears
                rearm_cnt   <= REARM_TICKS_50MS[7:0];
                ev_pw_ok_pc <= 1'b1;
            end
            // 2. Local 4-step sequential password FSM (PL PB1 -> PB2 -> PB1 -> PB2)
            //    Active only while alarm is ringing (alert_flag == 1)
            else if (alert_flag && any_pb_or_key) begin
                case (pw_step)
                    2'd0: begin
                        if (step1_match) begin
                            pw_step     <= 2'd1;
                            ev_pw_step1 <= 1'b1;
                        end else begin
                            pw_step     <= 2'd0;
                            ev_pw_error <= 1'b1;
                        end
                    end
                    2'd1: begin
                        if (step2_match) begin
                            pw_step     <= 2'd2;
                            ev_pw_step2 <= 1'b1;
                        end else begin
                            pw_step     <= 2'd0;
                            ev_pw_error <= 1'b1;
                        end
                    end
                    2'd2: begin
                        if (step3_match) begin
                            pw_step     <= 2'd3;
                            ev_pw_step3 <= 1'b1;
                        end else begin
                            pw_step     <= 2'd0;
                            ev_pw_error <= 1'b1;
                        end
                    end
                    2'd3: begin
                        if (step4_match) begin
                            pw_step      <= 2'd0;
                            alert_flag   <= 1'b0;
                            disarm_hold  <= 1'b1; // Hold disarmed state until obstacle clears
                            rearm_cnt    <= REARM_TICKS_50MS[7:0];
                            ev_pw_ok_nrm <= 1'b1;
                        end else begin
                            pw_step     <= 2'd0;
                            ev_pw_error <= 1'b1;
                        end
                    end
                endcase
            end
            // 3. Ultrasonic intrusion detection (Latches alert_flag = 1 until disarmed)
            else if (!alert_flag) begin
                pw_step <= 2'd0;

                // When obstacle is removed beyond threshold + 2cm hysteresis, release disarm_hold
                if (dist_valid && (distance_cm > (threshold_cm + 16'd2))) begin
                    disarm_hold <= 1'b0;
                end

                if (dist_valid && (rearm_cnt == 8'd0) && !disarm_hold) begin
                    if (threshold_cm > 16'd0 && distance_cm <= threshold_cm) begin
                        alert_flag       <= 1'b1;
                        sensed_dist_cm   <= distance_cm;
                        ev_alert_trigger <= 1'b1;
                    end
                end
            end
        end
    end

    // Composite Alarm Output Driver (LED[3:0], Buzzer, DC Motor PWM)
    always @(posedge clk) begin
        if (rst) begin
            blink_cnt    <= 8'd0;
            blink_phase  <= 1'b1;
            led          <= 4'b0000;
            buzzer       <= 1'b0;
            motor_in1    <= 1'b0;
            motor_in2    <= 1'b0;
            motor_nsleep <= 1'b0;
        end else if (alert_flag) begin
            if (tick_50ms) begin
                if (blink_cnt >= BLINK_TICKS_50MS - 1) begin
                    blink_cnt   <= 8'd0;
                    blink_phase <= ~blink_phase;
                end else begin
                    blink_cnt <= blink_cnt + 8'd1;
                end
            end

            led          <= blink_phase ? 4'b1111 : 4'b0000;
            buzzer       <= ~blink_phase; // Alternates with LED blink (or active tone)
            motor_nsleep <= 1'b1;         // Wake DRV8848
            motor_in1    <= 1'b0;
            motor_in2    <= (pwm_us_cnt < 10'd750); // 75% PWM duty cycle
        end else begin
            blink_cnt    <= 8'd0;
            blink_phase  <= 1'b1;
            led          <= 4'b0000;
            buzzer       <= 1'b0;
            motor_nsleep <= 1'b0;
            motor_in1    <= 1'b0;
            motor_in2    <= 1'b0;
        end
    end

endmodule
