`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: clk_div
// Description: 50MHz System Clock Divider generating 1-clock enable ticks:
//              - tick_1us  : 1 us period   (50 clocks @ 50MHz)
//              - tick_2ms  : 2 ms period   (100,000 clocks @ 50MHz)
//              - tick_50ms : 50 ms period  (2,500,000 clocks @ 50MHz, NFR-01 <= 100ms)
//              - tick_1s   : 1 s period    (50,000,000 clocks @ 50MHz)
//////////////////////////////////////////////////////////////////////////////////

module clk_div #(
    parameter integer CLKS_PER_US   = 50,
    parameter integer CLKS_PER_2MS  = 100_000,
    parameter integer CLKS_PER_50MS = 2_500_000,
    parameter integer CLKS_PER_1S   = 50_000_000
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_1us,
    output reg  tick_2ms,
    output reg  tick_50ms,
    output reg  tick_1s
);

    reg [31:0] cnt_1us;
    reg [31:0] cnt_2ms;
    reg [31:0] cnt_50ms;
    reg [31:0] cnt_1s;

    always @(posedge clk) begin
        if (rst) begin
            cnt_1us   <= 32'd0;
            cnt_2ms   <= 32'd0;
            cnt_50ms  <= 32'd0;
            cnt_1s    <= 32'd0;
            tick_1us  <= 1'b0;
            tick_2ms  <= 1'b0;
            tick_50ms <= 1'b0;
            tick_1s   <= 1'b0;
        end else begin
            // 1 us tick
            if (cnt_1us >= CLKS_PER_US - 1) begin
                cnt_1us  <= 32'd0;
                tick_1us <= 1'b1;
            end else begin
                cnt_1us  <= cnt_1us + 32'd1;
                tick_1us <= 1'b0;
            end

            // 2 ms tick (FND dynamic scan)
            if (cnt_2ms >= CLKS_PER_2MS - 1) begin
                cnt_2ms  <= 32'd0;
                tick_2ms <= 1'b1;
            end else begin
                cnt_2ms  <= cnt_2ms + 32'd1;
                tick_2ms <= 1'b0;
            end

            // 50 ms tick (Ultrasonic trigger period <= 100ms for NFR-01)
            if (cnt_50ms >= CLKS_PER_50MS - 1) begin
                cnt_50ms  <= 32'd0;
                tick_50ms <= 1'b1;
            end else begin
                cnt_50ms  <= cnt_50ms + 32'd1;
                tick_50ms <= 1'b0;
            end

            // 1 s tick (UART periodic report & clock base)
            if (cnt_1s >= CLKS_PER_1S - 1) begin
                cnt_1s  <= 32'd0;
                tick_1s <= 1'b1;
            end else begin
                cnt_1s  <= cnt_1s + 32'd1;
                tick_1s <= 1'b0;
            end
        end
    end

endmodule
