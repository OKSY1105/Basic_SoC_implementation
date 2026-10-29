`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: clock_fnd_ctrl
// Description: 24-Hour Digital Clock (HH:MM) & CORE-5300 4-Digit 7-Segment
//              Dynamic Multiplexing Controller (F-01, NFR-03).
//              - fnd_digit[3:0] (U12, T12, T10, T11): Active High (1 = ON)
//              - fnd_seg[7:0]   (dp, g, f, e, d, c, b, a): Active Low (0 = ON)
//////////////////////////////////////////////////////////////////////////////////

module clock_fnd_ctrl #(
    parameter integer SEC_PER_MIN = 6 // 6s per minute (matches ATmega128 demo speed; set 60 for real time)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_2ms,
    input  wire        tick_1s,
    input  wire [15:0] distance_cm,
    output reg  [4:0]  hour,
    output reg  [5:0]  minute,
    output reg  [3:0]  fnd_digit,
    output reg  [7:0]  fnd_seg
);

    reg [7:0] sec_cnt;
    reg [1:0] scan_idx;

    // 24-hour digital clock counter (NFR-03: resets to 00:00)
    always @(posedge clk) begin
        if (rst) begin
            sec_cnt <= 8'd0;
            minute  <= 6'd0;
            hour    <= 5'd0;
        end else if (tick_1s) begin
            if (sec_cnt >= SEC_PER_MIN - 1) begin
                sec_cnt <= 8'd0;
                if (minute >= 6'd59) begin
                    minute <= 6'd0;
                    if (hour >= 5'd23)
                        hour <= 5'd0;
                    else
                        hour <= hour + 5'd1;
                end else begin
                    minute <= minute + 6'd1;
                end
            end else begin
                sec_cnt <= sec_cnt + 8'd1;
            end
        end
    end

    // 2ms per digit dynamic scan (8ms full cycle for 4 digits)
    always @(posedge clk) begin
        if (rst) begin
            scan_idx <= 2'd0;
        end else if (tick_2ms) begin
            scan_idx <= scan_idx + 2'd1;
        end
    end

    // Distance 7-Segment display logic:
    // If distance_cm < 100 (e.g. Distance:0012 -> 12cm):
    //   Digit 3: (distance_cm / 10) % 10  ('1')
    //   Digit 2: distance_cm % 10         ('2.')  (DP lit)
    //   Digit 1: 0                        ('0')
    //   Digit 0: 0                        ('0')
    //   -> Displays "12.00"
    // If distance_cm >= 100 (e.g. Distance:0182 -> 182cm):
    //   Digit 3: (distance_cm / 100) % 10 ('1')
    //   Digit 2: (distance_cm / 10) % 10  ('8')
    //   Digit 1: distance_cm % 10         ('2.')  (DP lit)
    //   Digit 0: 0                        ('0')
    //   -> Displays "182.0"
    reg [3:0] reg_d3;
    reg [3:0] reg_d2;
    reg [3:0] reg_d1;
    reg [3:0] reg_d0;
    reg       reg_dp2;
    reg       reg_dp1;

    always @(posedge clk) begin
        if (rst) begin
            reg_d3  <= 4'd0;
            reg_d2  <= 4'd0;
            reg_d1  <= 4'd0;
            reg_d0  <= 4'd0;
            reg_dp2 <= 1'b1;
            reg_dp1 <= 1'b0;
        end else begin
            if (distance_cm < 16'd100) begin
                // 100cm 미만: 거리값.00 표출 (예: 12cm -> 12.00)
                reg_d3  <= (distance_cm / 16'd10) % 16'd10;
                reg_d2  <= distance_cm % 16'd10;
                reg_d1  <= 4'd0;
                reg_d0  <= 4'd0;
                reg_dp2 <= 1'b1;
                reg_dp1 <= 1'b0;
            end else begin
                // 100cm 이상: 0000 표출
                reg_d3  <= 4'd0;
                reg_d2  <= 4'd0;
                reg_d1  <= 4'd0;
                reg_d0  <= 4'd0;
                reg_dp2 <= 1'b0;
                reg_dp1 <= 1'b0;
            end
        end
    end

    reg [3:0] cur_bcd;
    reg       cur_dp_on;

    always @(*) begin
        case (scan_idx)
            2'd0: begin
                fnd_digit = 4'b0001; // Digit 0 (rightmost)
                cur_bcd   = reg_d0;
                cur_dp_on = 1'b0;
            end
            2'd1: begin
                fnd_digit = 4'b0010; // Digit 1
                cur_bcd   = reg_d1;
                cur_dp_on = reg_dp1;
            end
            2'd2: begin
                fnd_digit = 4'b0100; // Digit 2
                cur_bcd   = reg_d2;
                cur_dp_on = reg_dp2;
            end
            default: begin
                fnd_digit = 4'b1000; // Digit 3 (leftmost)
                cur_bcd   = reg_d3;
                cur_dp_on = 1'b0;
            end
        endcase
    end

    // Common Anode (Active Low) 7-Segment lookup table: {g, f, e, d, c, b, a}
    reg [6:0] seg_pattern;
    always @(*) begin
        case (cur_bcd)
            4'd0: seg_pattern = 7'b100_0000; // 0xC0
            4'd1: seg_pattern = 7'b111_1001; // 0xF9
            4'd2: seg_pattern = 7'b010_0100; // 0xA4
            4'd3: seg_pattern = 7'b011_0000; // 0xB0
            4'd4: seg_pattern = 7'b001_1001; // 0x99
            4'd5: seg_pattern = 7'b001_0010; // 0x92
            4'd6: seg_pattern = 7'b000_0010; // 0x82
            4'd7: seg_pattern = 7'b111_1000; // 0xD8
            4'd8: seg_pattern = 7'b000_0000; // 0x80
            4'd9: seg_pattern = 7'b001_1000; // 0x98
            default: seg_pattern = 7'b111_1111;
        endcase
        fnd_seg = {~cur_dp_on, seg_pattern};
    end

endmodule
