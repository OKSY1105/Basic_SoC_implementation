`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ultrasonic_ctrl
// Description: HC-SR04 Ultrasonic Distance Controller with:
//              - 50ms measurement cycle (NFR-01: < 100ms response time)
//              - 10us Trigger pulse generation
//              - Echo pulse width counter in us (/ 58 -> cm)
//              - 5-Sample Moving Average Filter (NFR-05 & Exception Scenario 3)
//////////////////////////////////////////////////////////////////////////////////

module ultrasonic_ctrl #(
    parameter integer TRIG_PULSE_US        = 10,
    parameter integer WAIT_ECHO_TIMEOUT_US = 10_000, // 10ms wait for Echo rise
    parameter integer ECHO_MAX_US          = 30_000  // 30ms max Echo high width
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_1us,
    input  wire        tick_50ms,
    input  wire        sonar_echo,
    output reg         sonar_trig,
    output reg  [15:0] distance_cm,   // 5-sample moving average distance (cm)
    output reg  [15:0] raw_dist_cm,   // Most recent single measurement (cm)
    output reg         dist_valid,    // 1-clock pulse when moving average is updated
    output reg         err_sonar,     // 1-clock pulse if Echo never rises (ERR:SONAR)
    output reg         err_range      // 1-clock pulse if Echo exceeds max range (ERR:RANGE)
);

    localparam [2:0] S_IDLE      = 3'd0,
                     S_TRIG      = 3'd1,
                     S_WAIT_HIGH = 3'd2,
                     S_MEAS_HIGH = 3'd3,
                     S_CALC_RAW  = 3'd4,
                     S_CALC_SUM  = 3'd5,
                     S_CALC_AVG  = 3'd6;

    reg [2:0]  state;
    reg        echo_s0, echo_s1;
    reg [15:0] us_cnt;

    // 5-sample moving average shift register & pipeline registers (NFR-05)
    reg [15:0] sample_buf [0:4];
    reg [2:0]  sample_count;
    reg [18:0] sum_5_reg;
    integer    i;

    wire [15:0] calc_cm = us_cnt / 16'd58;

    always @(posedge clk) begin
        if (rst) begin
            echo_s0      <= 1'b0;
            echo_s1      <= 1'b0;
            state        <= S_IDLE;
            sonar_trig   <= 1'b0;
            us_cnt       <= 16'd0;
            distance_cm  <= 16'd100;
            raw_dist_cm  <= 16'd100;
            sum_5_reg    <= 19'd500;
            dist_valid   <= 1'b0;
            err_sonar    <= 1'b0;
            err_range    <= 1'b0;
            sample_count <= 3'd0;
            for (i = 0; i < 5; i = i + 1) begin
                sample_buf[i] <= 16'd100;
            end
        end else begin
            echo_s0    <= sonar_echo;
            echo_s1    <= echo_s0;
            dist_valid <= 1'b0;
            err_sonar  <= 1'b0;
            err_range  <= 1'b0;

            case (state)
                S_IDLE: begin
                    sonar_trig <= 1'b0;
                    us_cnt     <= 16'd0;
                    if (tick_50ms) begin
                        sonar_trig <= 1'b1;
                        state      <= S_TRIG;
                    end
                end

                S_TRIG: begin
                    if (tick_1us) begin
                        if (us_cnt >= TRIG_PULSE_US - 1) begin
                            sonar_trig <= 1'b0;
                            us_cnt     <= 16'd0;
                            state      <= S_WAIT_HIGH;
                        end else begin
                            us_cnt <= us_cnt + 16'd1;
                        end
                    end
                end

                S_WAIT_HIGH: begin
                    if (echo_s1) begin
                        us_cnt <= 16'd0;
                        state  <= S_MEAS_HIGH;
                    end else if (tick_1us) begin
                        if (us_cnt >= WAIT_ECHO_TIMEOUT_US) begin
                            err_sonar <= 1'b1;
                            // No current measurement: discard stale samples and
                            // use the existing >=100cm display/telemetry sentinel.
                            distance_cm  <= 16'd100;
                            raw_dist_cm  <= 16'd100;
                            sample_count <= 3'd0;
                            sum_5_reg    <= 19'd500;
                            for (i = 0; i < 5; i = i + 1)
                                sample_buf[i] <= 16'd100;
                            state     <= S_IDLE;
                        end else begin
                            us_cnt <= us_cnt + 16'd1;
                        end
                    end
                end

                S_MEAS_HIGH: begin
                    if (!echo_s1) begin
                        state <= S_CALC_RAW;
                    end else if (tick_1us) begin
                        if (us_cnt >= ECHO_MAX_US) begin
                            err_range <= 1'b1;
                            distance_cm  <= 16'd100;
                            raw_dist_cm  <= 16'd100;
                            sample_count <= 3'd0;
                            sum_5_reg    <= 19'd500;
                            for (i = 0; i < 5; i = i + 1)
                                sample_buf[i] <= 16'd100;
                            state     <= S_IDLE;
                        end else begin
                            us_cnt <= us_cnt + 16'd1;
                        end
                    end
                end

                // Pipeline Stage 1: Divide us_cnt by 58 and push into 5-sample shift register
                S_CALC_RAW: begin
                    raw_dist_cm   <= calc_cm;
                    sample_buf[4] <= sample_buf[3];
                    sample_buf[3] <= sample_buf[2];
                    sample_buf[2] <= sample_buf[1];
                    sample_buf[1] <= sample_buf[0];
                    sample_buf[0] <= calc_cm;
                    if (sample_count < 3'd5) begin
                        sample_count <= sample_count + 3'd1;
                    end
                    state <= S_CALC_SUM;
                end

                // Pipeline Stage 2: Sum the 5 registered samples
                S_CALC_SUM: begin
                    sum_5_reg <= sample_buf[0] + sample_buf[1] + sample_buf[2] + sample_buf[3] + sample_buf[4];
                    state     <= S_CALC_AVG;
                end

                // Pipeline Stage 3: Divide 5-sample sum by 5 and assert dist_valid once 5 samples collected
                S_CALC_AVG: begin
                    if (sample_count >= 3'd5) begin
                        distance_cm <= sum_5_reg / 19'd5;
                        dist_valid  <= 1'b1;
                    end
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
