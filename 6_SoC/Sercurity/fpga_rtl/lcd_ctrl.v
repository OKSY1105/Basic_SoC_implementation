`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: lcd_ctrl
// Description: 16x2 Character Text LCD Controller (S6A0069 / HD44780 compatible)
//              Displays security surveillance state in English:
//              - Deactivated (SW all OFF):
//                  Line 1: "GUARD: DEACTIVE "
//                  Line 2: "MONITORING OFF  "
//              - Active (SW ON, normal monitoring):
//                  Line 1: "GUARD: ACTIVE   "
//                  Line 2: "MONITORING ON   "
//              - Active (Intrusion Alert):
//                  Line 1: "GUARD: ALARM!   "
//                  Line 2: "INTRUDER DETECT!" (or "PW STEP: X/4... ")
//              - Active (Disarmed, obstacle clearance wait):
//                  Line 1: "GUARD: STOPPED  "
//                  Line 2: "CLEAR OBSTACLE! "
//////////////////////////////////////////////////////////////////////////////////

module lcd_ctrl #(
    parameter integer SIMULATION = 0
)(
    input  wire        clk,          // 50 MHz system clock
    input  wire        rst,
    input  wire        guard_active, // 1 when threshold_cm > 0, 0 when all SW OFF
    input  wire        alert_flag,   // 1 when intrusion alarm is active
    input  wire        disarm_hold,  // 1 when disarmed but waiting for obstacle clearance
    input  wire [1:0]  pw_step,      // 0..3: password entry progress
    output reg         lcd_rs,       // Register select (0: Command, 1: Data)
    output reg         lcd_e,        // Enable strobe (Active High)
    output reg  [7:0]  lcd_data      // 8-bit data bus (DB7..DB0)
);

    // Timing constants (@50MHz, 20ns clock cycle)
    localparam integer CNT_PWR_ON = SIMULATION ? 100 : 1_500_000; // 30ms (power-on delay)
    localparam integer CNT_E_HIGH = SIMULATION ? 5   : 50;        // 1us E pulse
    localparam integer CNT_E_WAIT = SIMULATION ? 10  : 3_000;     // 60us command execution delay
    localparam integer CNT_CLR    = SIMULATION ? 50  : 150_000;   // 3ms clear display delay
    localparam integer CNT_REF    = SIMULATION ? 200 : 5_000_000; // 100ms refresh period

    // 16-character ASCII buffers for Line 1 and Line 2
    reg [7:0] line1 [0:15];
    reg [7:0] line2 [0:15];

    always @(*) begin
        if (!guard_active) begin
            // 감시 비활성화 (Deactivated)
            line1[0]="G"; line1[1]="U"; line1[2]="A"; line1[3]="R"; line1[4]="D"; line1[5]=":"; line1[6]=" "; line1[7]="D";
            line1[8]="E"; line1[9]="A"; line1[10]="C"; line1[11]="T"; line1[12]="I"; line1[13]="V"; line1[14]="E"; line1[15]=" ";

            line2[0]="M"; line2[1]="O"; line2[2]="N"; line2[3]="I"; line2[4]="T"; line2[5]="O"; line2[6]="R"; line2[7]="I";
            line2[8]="N"; line2[9]="G"; line2[10]=" "; line2[11]="O"; line2[12]="F"; line2[13]="F"; line2[14]=" "; line2[15]=" ";
        end else if (disarm_hold) begin
            // 해제 완료 후 장애물 치우기 대기
            line1[0]="G"; line1[1]="U"; line1[2]="A"; line1[3]="R"; line1[4]="D"; line1[5]=":"; line1[6]=" "; line1[7]="S";
            line1[8]="T"; line1[9]="O"; line1[10]="P"; line1[11]="P"; line1[12]="E"; line1[13]="D"; line1[14]=" "; line1[15]=" ";

            line2[0]="C"; line2[1]="L"; line2[2]="E"; line2[3]="A"; line2[4]="R"; line2[5]=" "; line2[6]="O"; line2[7]="B";
            line2[8]="S"; line2[9]="T"; line2[10]="A"; line2[11]="C"; line2[12]="L"; line2[13]="E"; line2[14]="!"; line2[15]=" ";
        end else if (alert_flag) begin
            // 침입 경보 발령
            line1[0]="G"; line1[1]="U"; line1[2]="A"; line1[3]="R"; line1[4]="D"; line1[5]=":"; line1[6]=" "; line1[7]="A";
            line1[8]="L"; line1[9]="A"; line1[10]="R"; line1[11]="M"; line1[12]="!"; line1[13]=" "; line1[14]=" "; line1[15]=" ";

            if (pw_step == 2'd1) begin
                line2[0]="P"; line2[1]="W"; line2[2]=" "; line2[3]="S"; line2[4]="T"; line2[5]="E"; line2[6]="P"; line2[7]=":";
                line2[8]=" "; line2[9]="1"; line2[10]="/"; line2[11]="4"; line2[12]="."; line2[13]="."; line2[14]="."; line2[15]=" ";
            end else if (pw_step == 2'd2) begin
                line2[0]="P"; line2[1]="W"; line2[2]=" "; line2[3]="S"; line2[4]="T"; line2[5]="E"; line2[6]="P"; line2[7]=":";
                line2[8]=" "; line2[9]="2"; line2[10]="/"; line2[11]="4"; line2[12]="."; line2[13]="."; line2[14]="."; line2[15]=" ";
            end else if (pw_step == 2'd3) begin
                line2[0]="P"; line2[1]="W"; line2[2]=" "; line2[3]="S"; line2[4]="T"; line2[5]="E"; line2[6]="P"; line2[7]=":";
                line2[8]=" "; line2[9]="3"; line2[10]="/"; line2[11]="4"; line2[12]="."; line2[13]="."; line2[14]="."; line2[15]=" ";
            end else begin
                line2[0]="I"; line2[1]="N"; line2[2]="T"; line2[3]="R"; line2[4]="U"; line2[5]="D"; line2[6]="E"; line2[7]="R";
                line2[8]=" "; line2[9]="D"; line2[10]="E"; line2[11]="T"; line2[12]="E"; line2[13]="C"; line2[14]="T"; line2[15]="!";
            end
        end else begin
            // 감시 활성화 (Active, 평상시 대기)
            line1[0]="G"; line1[1]="U"; line1[2]="A"; line1[3]="R"; line1[4]="D"; line1[5]=":"; line1[6]=" "; line1[7]="A";
            line1[8]="C"; line1[9]="T"; line1[10]="I"; line1[11]="V"; line1[12]="E"; line1[13]=" "; line1[14]=" "; line1[15]=" ";

            line2[0]="M"; line2[1]="O"; line2[2]="N"; line2[3]="I"; line2[4]="T"; line2[5]="O"; line2[6]="R"; line2[7]="I";
            line2[8]="N"; line2[9]="G"; line2[10]=" "; line2[11]="O"; line2[12]="N"; line2[13]=" "; line2[14]=" "; line2[15]=" ";
        end
    end

    // FSM States
    localparam [2:0] S_PWR_ON = 3'd0,
                     S_INIT   = 3'd1,
                     S_REFRESH= 3'd2,
                     S_PULSE_E= 3'd3,
                     S_WAIT   = 3'd4,
                     S_IDLE   = 3'd5;

    reg [2:0]  state;
    reg [2:0]  ret_state;
    reg [23:0] timer_cnt;
    reg [23:0] wait_limit;
    reg [23:0] ref_cnt;
    reg [3:0]  init_step;
    reg [5:0]  data_step;

    // Detect state changes to trigger immediate LCD refresh
    reg prev_active;
    reg prev_alert;
    reg prev_hold;
    reg [1:0] prev_step;
    wire content_changed = (guard_active != prev_active) ||
                           (alert_flag   != prev_alert)  ||
                           (disarm_hold  != prev_hold)   ||
                           (pw_step      != prev_step);

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_PWR_ON;
            ret_state   <= S_PWR_ON;
            timer_cnt   <= 24'd0;
            wait_limit  <= 24'd0;
            ref_cnt     <= 24'd0;
            init_step   <= 4'd0;
            data_step   <= 6'd0;
            lcd_rs      <= 1'b0;
            lcd_e       <= 1'b0;
            lcd_data    <= 8'h00;
            prev_active <= 1'b0;
            prev_alert  <= 1'b0;
            prev_hold   <= 1'b0;
            prev_step   <= 2'd0;
        end else begin
            prev_active <= guard_active;
            prev_alert  <= alert_flag;
            prev_hold   <= disarm_hold;
            prev_step   <= pw_step;

            case (state)
                // 1. Power-on wait (30ms)
                S_PWR_ON: begin
                    lcd_rs   <= 1'b0;
                    lcd_e    <= 1'b0;
                    lcd_data <= 8'h00;
                    if (timer_cnt >= CNT_PWR_ON - 1) begin
                        timer_cnt <= 24'd0;
                        init_step <= 4'd0;
                        state     <= S_INIT;
                    end else begin
                        timer_cnt <= timer_cnt + 24'd1;
                    end
                end

                // 2. Hardware LCD Initialization sequence
                S_INIT: begin
                    case (init_step)
                        4'd0: begin // Function Set 8-bit
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h38;
                            wait_limit <= CNT_CLR; // 5ms wait
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        4'd1: begin // Function Set 8-bit
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h38;
                            wait_limit <= CNT_E_WAIT;
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        4'd2: begin // Function Set 8-bit
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h38;
                            wait_limit <= CNT_E_WAIT;
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        4'd3: begin // Function Set 8-bit, 2-line, 5x8 font
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h38;
                            wait_limit <= CNT_E_WAIT;
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        4'd4: begin // Display ON, Cursor OFF, Blink OFF
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h0C;
                            wait_limit <= CNT_E_WAIT;
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        4'd5: begin // Clear Display
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h01;
                            wait_limit <= CNT_CLR; // 3ms clear
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        4'd6: begin // Entry Mode Set: Increment cursor, No display shift
                            lcd_rs     <= 1'b0;
                            lcd_data   <= 8'h06;
                            wait_limit <= CNT_E_WAIT;
                            init_step  <= init_step + 4'd1;
                            ret_state  <= S_INIT;
                            state      <= S_PULSE_E;
                        end
                        default: begin
                            data_step <= 6'd0;
                            state     <= S_REFRESH;
                        end
                    endcase
                end

                // 3. Screen Refresh sequence (Line 1 addr 0x80 -> 16 chars -> Line 2 addr 0xC0 -> 16 chars)
                S_REFRESH: begin
                    if (data_step == 6'd0) begin
                        // Command: Move to Line 1 Col 0 (0x80)
                        lcd_rs     <= 1'b0;
                        lcd_data   <= 8'h80;
                        wait_limit <= CNT_E_WAIT;
                        data_step  <= data_step + 6'd1;
                        ret_state  <= S_REFRESH;
                        state      <= S_PULSE_E;
                    end else if (data_step <= 6'd16) begin
                        // Data: 16 characters of Line 1
                        lcd_rs     <= 1'b1;
                        lcd_data   <= line1[data_step - 6'd1];
                        wait_limit <= CNT_E_WAIT;
                        data_step  <= data_step + 6'd1;
                        ret_state  <= S_REFRESH;
                        state      <= S_PULSE_E;
                    end else if (data_step == 6'd17) begin
                        // Command: Move to Line 2 Col 0 (0xC0)
                        lcd_rs     <= 1'b0;
                        lcd_data   <= 8'hC0;
                        wait_limit <= CNT_E_WAIT;
                        data_step  <= data_step + 6'd1;
                        ret_state  <= S_REFRESH;
                        state      <= S_PULSE_E;
                    end else if (data_step <= 6'd33) begin
                        // Data: 16 characters of Line 2
                        lcd_rs     <= 1'b1;
                        lcd_data   <= line2[data_step - 6'd18];
                        wait_limit <= CNT_E_WAIT;
                        data_step  <= data_step + 6'd1;
                        ret_state  <= S_REFRESH;
                        state      <= S_PULSE_E;
                    end else begin
                        data_step <= 6'd0;
                        ref_cnt   <= 24'd0;
                        state     <= S_IDLE;
                    end
                end

                // 4. Strobe LCD Enable (E) High for 1us, then proceed to wait
                S_PULSE_E: begin
                    lcd_e <= 1'b1;
                    if (timer_cnt >= CNT_E_HIGH - 1) begin
                        timer_cnt <= 24'd0;
                        lcd_e     <= 1'b0;
                        state     <= S_WAIT;
                    end else begin
                        timer_cnt <= timer_cnt + 24'd1;
                    end
                end

                // 5. Wait for LCD command execution
                S_WAIT: begin
                    if (timer_cnt >= wait_limit - 1) begin
                        timer_cnt <= 24'd0;
                        state     <= ret_state;
                    end else begin
                        timer_cnt <= timer_cnt + 24'd1;
                    end
                end

                // 6. Idle until next refresh period (100ms) or state content changes
                S_IDLE: begin
                    if (content_changed || (ref_cnt >= CNT_REF - 1)) begin
                        ref_cnt   <= 24'd0;
                        data_step <= 6'd0;
                        state     <= S_REFRESH;
                    end else begin
                        ref_cnt <= ref_cnt + 24'd1;
                    end
                end

                default: state <= S_PWR_ON;
            endcase
        end
    end

endmodule
