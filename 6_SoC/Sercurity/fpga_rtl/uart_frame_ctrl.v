`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_frame_ctrl
// Description: 9600bps 8N1 UART Transceiver + Frame Protocol Controller (F-04, NFR-02)
//              Frame Format: [SOF(0xAA)] + [TYPE(1B)] + [LEN(1B)] + [PAYLOAD(N)] + [CRC8(1B)]
//              CRC8 = TYPE ^ LEN ^ PAYLOAD[0] ^ ... ^ PAYLOAD[N-1]
//              - Parses incoming CMD "stop"/"STOP" -> asserts cmd_stop_pulse + sends ACK "OK"
//              - On CRC8 mismatch -> ignores command and sends ERR "E:CRC" (NFR-02)
//              - Sends startup ("SYS:START", "MD:GUARD"), password events, and 1s telemetry
//                ("Distance:XXXX", "Threshold:XXXX") 100% compatible with UART1_Repeater_GUI.py
//////////////////////////////////////////////////////////////////////////////////

module uart_frame_ctrl #(
    parameter integer CLKS_PER_BIT = 5208 // 50MHz / 9600bps = 5208
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_1s,
    input  wire        uart_rx,
    output reg         uart_tx,
    input  wire [15:0] distance_cm,
    input  wire [15:0] threshold_cm,
    input  wire        alert_flag,
    input  wire        ev_pw_step1,
    input  wire        ev_pw_step2,
    input  wire        ev_pw_step3,
    input  wire        ev_pw_ok_nrm,
    input  wire        ev_pw_ok_pc,
    input  wire        ev_pw_error,
    input  wire        ev_err_sonar,
    input  wire        ev_err_range,
    input  wire        ev_alert_trigger,
    input  wire [15:0] sensed_dist_cm,
    output reg         cmd_stop_pulse,
    output reg         crc_err_pulse
);

    localparam [7:0] UART_FRAME_SOF = 8'hAA,
                     UART_TYPE_DATA = 8'h01,
                     UART_TYPE_CMD  = 8'h02,
                     UART_TYPE_ACK  = 8'h03,
                     UART_TYPE_ERR  = 8'h04;

    // =========================================================================
    // 1. 8N1 UART Receiver
    // =========================================================================
    localparam [1:0] RX_S_IDLE  = 2'd0,
                     RX_S_START = 2'd1,
                     RX_S_DATA  = 2'd2,
                     RX_S_STOP  = 2'd3;

    reg        rx_sync0, rx_sync1;
    reg [1:0]  rx_phy_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_idx;
    reg [7:0]  rx_shift;
    reg [7:0]  rx_byte;
    reg        rx_valid;

    always @(posedge clk) begin
        if (rst) begin
            rx_sync0     <= 1'b1;
            rx_sync1     <= 1'b1;
            rx_phy_state <= RX_S_IDLE;
            rx_clk_cnt   <= 16'd0;
            rx_bit_idx   <= 3'd0;
            rx_shift     <= 8'd0;
            rx_byte      <= 8'd0;
            rx_valid     <= 1'b0;
        end else begin
            rx_sync0 <= uart_rx;
            rx_sync1 <= rx_sync0;
            rx_valid <= 1'b0;

            case (rx_phy_state)
                RX_S_IDLE: begin
                    rx_clk_cnt <= 16'd0;
                    rx_bit_idx <= 3'd0;
                    if (!rx_sync1) begin
                        rx_phy_state <= RX_S_START;
                    end
                end

                RX_S_START: begin
                    if (rx_clk_cnt >= (CLKS_PER_BIT / 2) - 1) begin
                        if (!rx_sync1) begin
                            rx_clk_cnt   <= 16'd0;
                            rx_phy_state <= RX_S_DATA;
                        end else begin
                            rx_phy_state <= RX_S_IDLE;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end

                RX_S_DATA: begin
                    if (rx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        rx_clk_cnt           <= 16'd0;
                        rx_shift[rx_bit_idx] <= rx_sync1;
                        if (rx_bit_idx == 3'd7) begin
                            rx_bit_idx   <= 3'd0;
                            rx_phy_state <= RX_S_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 3'd1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end

                RX_S_STOP: begin
                    if (rx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        if (rx_sync1) begin
                            rx_clk_cnt   <= 16'd0;
                            rx_byte      <= rx_shift;
                            rx_valid     <= 1'b1;
                            rx_phy_state <= RX_S_IDLE;
                        end
                        // If rx_sync1 is still 0 (framing error / break), wait until line returns High (1)
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // 2. RX Frame Parser FSM (SOF -> TYPE -> LEN -> PAYLOAD -> CRC8)
    // =========================================================================
    localparam [2:0] P_WAIT_SOF     = 3'd0,
                     P_WAIT_TYPE    = 3'd1,
                     P_WAIT_LEN     = 3'd2,
                     P_WAIT_PAYLOAD = 3'd3,
                     P_WAIT_CRC     = 3'd4;

    reg [2:0] p_state;
    reg [7:0] rx_type;
    reg [7:0] rx_len;
    reg [7:0] rx_pay_idx;
    reg [7:0] rx_crc_acc;
    reg [7:0] rx_p0, rx_p1, rx_p2, rx_p3;

    reg req_ack_ok;
    reg req_err_crc;
    reg req_status;

    always @(posedge clk) begin
        if (rst) begin
            p_state        <= P_WAIT_SOF;
            rx_type        <= 8'd0;
            rx_len         <= 8'd0;
            rx_pay_idx     <= 8'd0;
            rx_crc_acc     <= 8'd0;
            rx_p0          <= 8'd0;
            rx_p1          <= 8'd0;
            rx_p2          <= 8'd0;
            rx_p3          <= 8'd0;
            cmd_stop_pulse <= 1'b0;
            crc_err_pulse  <= 1'b0;
            req_ack_ok     <= 1'b0;
            req_err_crc    <= 1'b0;
            req_status     <= 1'b0;
        end else begin
            cmd_stop_pulse <= 1'b0;
            crc_err_pulse  <= 1'b0;
            req_ack_ok     <= 1'b0;
            req_err_crc    <= 1'b0;
            req_status     <= 1'b0;

            if (rx_valid) begin
                case (p_state)
                    P_WAIT_SOF: begin
                        if (rx_byte == UART_FRAME_SOF)
                            p_state <= P_WAIT_TYPE;
                    end

                    P_WAIT_TYPE: begin
                        rx_type <= rx_byte;
                        p_state <= P_WAIT_LEN;
                    end

                    P_WAIT_LEN: begin
                        if (rx_byte > 8'd28) begin
                            p_state <= P_WAIT_SOF;
                        end else begin
                            rx_len     <= rx_byte;
                            rx_pay_idx <= 8'd0;
                            rx_crc_acc <= rx_type ^ rx_byte;
                            p_state    <= (rx_byte == 8'd0) ? P_WAIT_CRC : P_WAIT_PAYLOAD;
                        end
                    end

                    P_WAIT_PAYLOAD: begin
                        rx_crc_acc <= rx_crc_acc ^ rx_byte;
                        if (rx_pay_idx == 8'd0) rx_p0 <= rx_byte;
                        if (rx_pay_idx == 8'd1) rx_p1 <= rx_byte;
                        if (rx_pay_idx == 8'd2) rx_p2 <= rx_byte;
                        if (rx_pay_idx == 8'd3) rx_p3 <= rx_byte;

                        if (rx_pay_idx + 8'd1 >= rx_len)
                            p_state <= P_WAIT_CRC;
                        else
                            rx_pay_idx <= rx_pay_idx + 8'd1;
                    end

                    P_WAIT_CRC: begin
                        p_state <= P_WAIT_SOF;
                        if (rx_byte == rx_crc_acc) begin
                            if (rx_type == UART_TYPE_CMD) begin
                                req_ack_ok <= 1'b1;
                                if (rx_len == 8'd4 &&
                                   (({rx_p0, rx_p1, rx_p2, rx_p3} == "stop") ||
                                    ({rx_p0, rx_p1, rx_p2, rx_p3} == "STOP"))) begin
                                    cmd_stop_pulse <= 1'b1;
                                end else if (rx_len == 8'd4 &&
                                   (({rx_p0, rx_p1, rx_p2, rx_p3} == "read") ||
                                    ({rx_p0, rx_p1, rx_p2, rx_p3} == "READ"))) begin
                                    req_status <= 1'b1;
                                end
                            end
                        end else begin
                            crc_err_pulse <= 1'b1;
                            req_err_crc   <= 1'b1;
                        end
                    end

                    default: p_state <= P_WAIT_SOF;
                endcase
            end
        end
    end

    // =========================================================================
    // 3. 8N1 UART Transmitter
    // =========================================================================
    localparam [1:0] TX_S_IDLE  = 2'd0,
                     TX_S_START = 2'd1,
                     TX_S_DATA  = 2'd2,
                     TX_S_STOP  = 2'd3;

    reg [1:0]  tx_phy_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_idx;
    reg [7:0]  tx_shift;
    reg        tx_start;
    reg [7:0]  tx_byte_in;
    reg        tx_busy;

    always @(posedge clk) begin
        if (rst) begin
            uart_tx      <= 1'b1;
            tx_phy_state <= TX_S_IDLE;
            tx_clk_cnt   <= 16'd0;
            tx_bit_idx   <= 3'd0;
            tx_shift     <= 8'd0;
            tx_busy      <= 1'b0;
        end else begin
            case (tx_phy_state)
                TX_S_IDLE: begin
                    uart_tx    <= 1'b1;
                    tx_clk_cnt <= 16'd0;
                    tx_bit_idx <= 3'd0;
                    if (tx_start) begin
                        tx_shift     <= tx_byte_in;
                        tx_busy      <= 1'b1;
                        uart_tx      <= 1'b0; // Start bit
                        tx_phy_state <= TX_S_START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                TX_S_START: begin
                    uart_tx <= 1'b0;
                    if (tx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        tx_clk_cnt   <= 16'd0;
                        uart_tx      <= tx_shift[0];
                        tx_phy_state <= TX_S_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
                    end
                end

                TX_S_DATA: begin
                    uart_tx <= tx_shift[tx_bit_idx];
                    if (tx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 16'd0;
                        if (tx_bit_idx == 3'd7) begin
                            tx_bit_idx   <= 3'd0;
                            uart_tx      <= 1'b1; // Stop bit
                            tx_phy_state <= TX_S_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 3'd1;
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
                    end
                end

                TX_S_STOP: begin
                    uart_tx <= 1'b1;
                    if (tx_clk_cnt >= CLKS_PER_BIT - 1) begin
                        tx_clk_cnt   <= 16'd0;
                        tx_busy      <= 1'b0;
                        tx_phy_state <= TX_S_IDLE;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // 4. TX Frame Queue & Packet Builder
    // =========================================================================
    reg pend_sys_start;
    reg pend_md_guard;
    reg pend_err_crc;
    reg pend_ack_ok;
    reg pend_pw_ok_pc;
    reg pend_pw_ok_nrm;
    reg pend_pw_error;
    reg pend_pw_step1;
    reg pend_pw_step2;
    reg pend_pw_step3;
    reg pend_err_sonar;
    reg pend_err_range;
    reg pend_dist;
    reg pend_thresh;
    reg pend_intruder;
    reg pend_sensed_dist;
    reg [15:0] reg_sensed_dist;
    reg [15:0] prev_threshold;
    reg pend_alarm_status;

    localparam [2:0] F_IDLE    = 3'd0,
                     F_SOF     = 3'd1,
                     F_TYPE    = 3'd2,
                     F_LEN     = 3'd3,
                     F_PAYLOAD = 3'd4,
                     F_CRC     = 3'd5,
                     F_WAIT    = 3'd6;

    reg [2:0] f_state;
    reg [2:0] f_next_state;
    reg [7:0] f_type;
    reg [7:0] f_len;
    reg [7:0] f_idx;
    reg [7:0] f_crc;
    reg [7:0] f_buf [0:31];
    integer   k;

    // 4-digit decimal ASCII digits for distance_cm, threshold_cm, and sensed_dist
    // When distance_cm >= 100cm, effective_dist is 0 -> sends "Distance:0000"
    wire [15:0] effective_dist = (distance_cm >= 16'd100) ? 16'd0 : distance_cm;
    wire [7:0] dist_d3 = 8'h30 + ((effective_dist  / 16'd1000) % 16'd10);
    wire [7:0] dist_d2 = 8'h30 + ((effective_dist  / 16'd100)  % 16'd10);
    wire [7:0] dist_d1 = 8'h30 + ((effective_dist  / 16'd10)   % 16'd10);
    wire [7:0] dist_d0 = 8'h30 + ( effective_dist              % 16'd10);

    wire [7:0] th_d3   = 8'h30 + ((threshold_cm / 16'd1000) % 16'd10);
    wire [7:0] th_d2   = 8'h30 + ((threshold_cm / 16'd100)  % 16'd10);
    wire [7:0] th_d1   = 8'h30 + ((threshold_cm / 16'd10)   % 16'd10);
    wire [7:0] th_d0   = 8'h30 + ( threshold_cm             % 16'd10);

    wire [15:0] effective_sense = (reg_sensed_dist >= 16'd100) ? 16'd0 : reg_sensed_dist;
    wire [7:0] sense_d3 = 8'h30 + ((effective_sense / 16'd1000) % 16'd10);
    wire [7:0] sense_d2 = 8'h30 + ((effective_sense / 16'd100)  % 16'd10);
    wire [7:0] sense_d1 = 8'h30 + ((effective_sense / 16'd10)   % 16'd10);
    wire [7:0] sense_d0 = 8'h30 + ( effective_sense             % 16'd10);

    always @(posedge clk) begin
        if (rst) begin
            pend_sys_start  <= 1'b1; // Send SYS:START on boot
            pend_md_guard   <= 1'b1; // Send MD:GUARD on boot (Always-on Guard Mode)
            pend_err_crc    <= 1'b0;
            pend_ack_ok     <= 1'b0;
            pend_pw_ok_pc   <= 1'b0;
            pend_pw_ok_nrm  <= 1'b0;
            pend_pw_error   <= 1'b0;
            pend_pw_step1   <= 1'b0;
            pend_pw_step2   <= 1'b0;
            pend_pw_step3   <= 1'b0;
            pend_err_sonar  <= 1'b0;
            pend_err_range  <= 1'b0;
            pend_dist       <= 1'b0;
            pend_thresh     <= 1'b1; // Send initial threshold once
            pend_intruder   <= 1'b0;
            pend_sensed_dist<= 1'b0;
            reg_sensed_dist <= 16'd0;
            prev_threshold  <= 16'd0;
            pend_alarm_status <= 1'b0;

            f_state        <= F_IDLE;
            f_next_state   <= F_IDLE;
            f_type         <= 8'd0;
            f_len          <= 8'd0;
            f_idx          <= 8'd0;
            f_crc          <= 8'd0;
            tx_start       <= 1'b0;
            tx_byte_in     <= 8'd0;
            for (k = 0; k < 32; k = k + 1) f_buf[k] <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            // Latch incoming event pulses
            if (ev_alert_trigger) begin
                pend_intruder    <= 1'b1;
                pend_sensed_dist <= 1'b1;
                reg_sensed_dist  <= sensed_dist_cm;
            end
            if (threshold_cm != prev_threshold) begin
                prev_threshold <= threshold_cm;
                pend_thresh    <= 1'b1; // Send threshold once when switch position changes
            end
            if (tick_1s) begin
                // Distance telemetry is independent of alarm enable and SW1..SW4.
                pend_dist <= 1'b1;
            end
            // Explicit snapshot on connection/reconnection; keep normal
            // Threshold telemetry limited to changes rather than every second.
            if (req_status) begin
                pend_dist         <= 1'b1;
                pend_thresh       <= 1'b1;
                pend_alarm_status <= 1'b1;
            end
            if (req_err_crc)   pend_err_crc   <= 1'b1;
            if (req_ack_ok)    pend_ack_ok    <= 1'b1;
            if (ev_pw_ok_pc)   pend_pw_ok_pc  <= 1'b1;
            if (ev_pw_ok_nrm)  pend_pw_ok_nrm <= 1'b1;
            if (ev_pw_error)   pend_pw_error  <= 1'b1;
            if (ev_pw_step1)   pend_pw_step1  <= 1'b1;
            if (ev_pw_step2)   pend_pw_step2  <= 1'b1;
            if (ev_pw_step3)   pend_pw_step3  <= 1'b1;
            if (ev_err_sonar)  pend_err_sonar <= 1'b1;
            if (ev_err_range)  pend_err_range <= 1'b1;

            case (f_state)
                F_IDLE: begin
                    if (!tx_busy) begin
                        if (pend_intruder) begin
                            pend_intruder <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd18;
                            f_buf[0]<="I"; f_buf[1]<="n"; f_buf[2]<="t"; f_buf[3]<="r";
                            f_buf[4]<="u"; f_buf[5]<="d"; f_buf[6]<="e"; f_buf[7]<="r";
                            f_buf[8]<=" "; f_buf[9]<="d"; f_buf[10]<="e"; f_buf[11]<="t";
                            f_buf[12]<="e"; f_buf[13]<="c"; f_buf[14]<="t"; f_buf[15]<="i";
                            f_buf[16]<="o"; f_buf[17]<="n";
                            f_state <= F_SOF;
                        end else if (pend_sensed_dist) begin
                            pend_sensed_dist <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd13;
                            f_buf[0]<="D"; f_buf[1]<="i"; f_buf[2]<="s"; f_buf[3]<="t";
                            f_buf[4]<="a"; f_buf[5]<="n"; f_buf[6]<="c"; f_buf[7]<="e";
                            f_buf[8]<=":"; f_buf[9]<=sense_d3; f_buf[10]<=sense_d2;
                            f_buf[11]<=sense_d1; f_buf[12]<=sense_d0;
                            f_state <= F_SOF;
                        end else if (pend_err_crc) begin
                            pend_err_crc <= 1'b0;
                            f_type <= UART_TYPE_ERR; f_len <= 8'd5;
                            f_buf[0]<="E"; f_buf[1]<=":"; f_buf[2]<="C"; f_buf[3]<="R"; f_buf[4]<="C";
                            f_state <= F_SOF;
                        end else if (pend_ack_ok) begin
                            pend_ack_ok <= 1'b0;
                            f_type <= UART_TYPE_ACK; f_len <= 8'd2;
                            f_buf[0]<="O"; f_buf[1]<="K";
                            f_state <= F_SOF;
                        end else if (pend_pw_ok_pc) begin
                            pend_pw_ok_pc <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd8;
                            f_buf[0]<="P"; f_buf[1]<="W"; f_buf[2]<=":"; f_buf[3]<="O";
                            f_buf[4]<="K"; f_buf[5]<="_"; f_buf[6]<="P"; f_buf[7]<="C";
                            f_state <= F_SOF;
                        end else if (pend_pw_ok_nrm) begin
                            pend_pw_ok_nrm <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd9;
                            f_buf[0]<="P"; f_buf[1]<="W"; f_buf[2]<=":"; f_buf[3]<="O";
                            f_buf[4]<="K"; f_buf[5]<="_"; f_buf[6]<="N"; f_buf[7]<="R"; f_buf[8]<="M";
                            f_state <= F_SOF;
                        end else if (pend_pw_error) begin
                            pend_pw_error <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd8;
                            f_buf[0]<="P"; f_buf[1]<="W"; f_buf[2]<=":"; f_buf[3]<="E";
                            f_buf[4]<="R"; f_buf[5]<="R"; f_buf[6]<="O"; f_buf[7]<="R";
                            f_state <= F_SOF;
                        end else if (pend_pw_step1) begin
                            pend_pw_step1 <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd8;
                            f_buf[0]<="P"; f_buf[1]<="W"; f_buf[2]<=":"; f_buf[3]<="S";
                            f_buf[4]<="T"; f_buf[5]<="E"; f_buf[6]<="P"; f_buf[7]<="1";
                            f_state <= F_SOF;
                        end else if (pend_pw_step2) begin
                            pend_pw_step2 <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd8;
                            f_buf[0]<="P"; f_buf[1]<="W"; f_buf[2]<=":"; f_buf[3]<="S";
                            f_buf[4]<="T"; f_buf[5]<="E"; f_buf[6]<="P"; f_buf[7]<="2";
                            f_state <= F_SOF;
                        end else if (pend_pw_step3) begin
                            pend_pw_step3 <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd8;
                            f_buf[0]<="P"; f_buf[1]<="W"; f_buf[2]<=":"; f_buf[3]<="S";
                            f_buf[4]<="T"; f_buf[5]<="E"; f_buf[6]<="P"; f_buf[7]<="3";
                            f_state <= F_SOF;
                        end else if (pend_sys_start) begin
                            pend_sys_start <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd9;
                            f_buf[0]<="S"; f_buf[1]<="Y"; f_buf[2]<="S"; f_buf[3]<=":";
                            f_buf[4]<="S"; f_buf[5]<="T"; f_buf[6]<="A"; f_buf[7]<="R"; f_buf[8]<="T";
                            f_state <= F_SOF;
                        end else if (pend_md_guard) begin
                            pend_md_guard <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd8;
                            f_buf[0]<="M"; f_buf[1]<="D"; f_buf[2]<=":"; f_buf[3]<="G";
                            f_buf[4]<="U"; f_buf[5]<="A"; f_buf[6]<="R"; f_buf[7]<="D";
                            f_state <= F_SOF;
                        end else if (pend_err_sonar) begin
                            pend_err_sonar <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd9;
                            f_buf[0]<="E"; f_buf[1]<="R"; f_buf[2]<="R"; f_buf[3]<=":";
                            f_buf[4]<="S"; f_buf[5]<="O"; f_buf[6]<="N"; f_buf[7]<="A"; f_buf[8]<="R";
                            f_state <= F_SOF;
                        end else if (pend_err_range) begin
                            pend_err_range <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd9;
                            f_buf[0]<="E"; f_buf[1]<="R"; f_buf[2]<="R"; f_buf[3]<=":";
                            f_buf[4]<="R"; f_buf[5]<="A"; f_buf[6]<="N"; f_buf[7]<="G"; f_buf[8]<="E";
                            f_state <= F_SOF;
                        end else if (pend_dist) begin
                            pend_dist <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd13;
                            f_buf[0]<="D"; f_buf[1]<="i"; f_buf[2]<="s"; f_buf[3]<="t";
                            f_buf[4]<="a"; f_buf[5]<="n"; f_buf[6]<="c"; f_buf[7]<="e";
                            f_buf[8]<=":"; f_buf[9]<=dist_d3; f_buf[10]<=dist_d2;
                            f_buf[11]<=dist_d1; f_buf[12]<=dist_d0;
                            f_state <= F_SOF;
                        end else if (pend_alarm_status) begin
                            pend_alarm_status <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd7;
                            f_buf[0]<="A"; f_buf[1]<="l"; f_buf[2]<="a";
                            f_buf[3]<="r"; f_buf[4]<="m"; f_buf[5]<=":";
                            f_buf[6]<=alert_flag ? "1" : "0";
                            f_state <= F_SOF;
                        end else if (pend_thresh) begin
                            pend_thresh <= 1'b0;
                            f_type <= UART_TYPE_DATA; f_len <= 8'd14;
                            f_buf[0]<="T"; f_buf[1]<="h"; f_buf[2]<="r"; f_buf[3]<="e";
                            f_buf[4]<="s"; f_buf[5]<="h"; f_buf[6]<="o"; f_buf[7]<="l";
                            f_buf[8]<="d"; f_buf[9]<=":"; f_buf[10]<=th_d3; f_buf[11]<=th_d2;
                            f_buf[12]<=th_d1; f_buf[13]<=th_d0;
                            f_state <= F_SOF;
                        end
                    end
                end

                F_SOF: begin
                    tx_byte_in   <= UART_FRAME_SOF;
                    tx_start     <= 1'b1;
                    f_crc        <= 8'd0;
                    f_idx        <= 8'd0;
                    f_next_state <= F_TYPE;
                    f_state      <= F_WAIT;
                end

                F_TYPE: begin
                    tx_byte_in   <= f_type;
                    tx_start     <= 1'b1;
                    f_crc        <= f_type;
                    f_next_state <= F_LEN;
                    f_state      <= F_WAIT;
                end

                F_LEN: begin
                    tx_byte_in   <= f_len;
                    tx_start     <= 1'b1;
                    f_crc        <= f_crc ^ f_len;
                    f_next_state <= (f_len == 8'd0) ? F_CRC : F_PAYLOAD;
                    f_state      <= F_WAIT;
                end

                F_PAYLOAD: begin
                    tx_byte_in <= f_buf[f_idx];
                    tx_start   <= 1'b1;
                    f_crc      <= f_crc ^ f_buf[f_idx];
                    if (f_idx + 8'd1 >= f_len) begin
                        f_next_state <= F_CRC;
                    end else begin
                        f_idx        <= f_idx + 8'd1;
                        f_next_state <= F_PAYLOAD;
                    end
                    f_state <= F_WAIT;
                end

                F_CRC: begin
                    tx_byte_in   <= f_crc;
                    tx_start     <= 1'b1;
                    f_next_state <= F_IDLE;
                    f_state      <= F_WAIT;
                end

                F_WAIT: begin
                    // Wait 1 cycle for tx_busy to rise, then wait for tx_busy to clear
                    if (!tx_start && !tx_busy) begin
                        f_state <= f_next_state;
                    end
                end

                default: f_state <= F_IDLE;
            endcase
        end
    end

endmodule
