`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: debounce_edge
// Description: 2-FF Synchronizer + 20ms Hardware Debouncer (NFR-04) +
//              One-shot Rising Edge Detector for CORE-5300 Touch Keypad & Buttons.
//////////////////////////////////////////////////////////////////////////////////

module debounce_edge #(
    parameter integer DEBOUNCE_CYCLES = 1_000_000 // 20ms @ 50MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire noisy_in,
    output reg  clean_out,
    output reg  rise_pulse
);

    reg sync_0, sync_1;
    reg prev_clean;
    reg [31:0] cnt;

    always @(posedge clk) begin
        if (rst) begin
            sync_0     <= 1'b0;
            sync_1     <= 1'b0;
            clean_out  <= 1'b0;
            prev_clean <= 1'b0;
            cnt        <= 32'd0;
            rise_pulse <= 1'b0;
        end else begin
            // 2-stage metastability synchronizer
            sync_0 <= noisy_in;
            sync_1 <= sync_0;

            // 20ms stability counter (NFR-04)
            if (sync_1 == clean_out) begin
                cnt <= 32'd0;
            end else begin
                if (cnt >= DEBOUNCE_CYCLES - 1) begin
                    clean_out <= sync_1;
                    cnt       <= 32'd0;
                end else begin
                    cnt <= cnt + 32'd1;
                end
            end

            // Rising edge one-shot pulse
            prev_clean <= clean_out;
            rise_pulse <= (clean_out && !prev_clean);
        end
    end

endmodule
