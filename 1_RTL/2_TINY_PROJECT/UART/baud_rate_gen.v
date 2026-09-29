module baud_rate_gen #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115200
)(
    i_clk,
    i_rst_n,
    o_baud_tick,
    o_os_tick
);

input  i_clk;
input  i_rst_n;

output reg o_baud_tick;
output reg o_os_tick;


/*
 * UART RX oversampling tick = BAUD_RATE x 16
 *
 * 100 MHz / (115200 x 16) = about 54 clocks
 */
localparam integer OS_RATE = BAUD_RATE * 16;
localparam integer OS_DIV  = (CLK_FREQ_HZ + (OS_RATE / 2)) / OS_RATE;

localparam integer OS_CNT_WIDTH =
    (OS_DIV <= 1) ? 1 : $clog2(OS_DIV);

reg [OS_CNT_WIDTH-1:0] r_os_cnt;
reg [3:0]              r_baud_cnt;


/************************************************
 * os_tick  : BAUD_RATE x 16
 * baud_tick: BAUD_RATE x 1
 ************************************************/
always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        r_os_cnt    <= {OS_CNT_WIDTH{1'b0}};
        r_baud_cnt  <= 4'd0;

        o_os_tick   <= 1'b0;
        o_baud_tick <= 1'b0;
    end
    else begin
        // tick signals are one-system-clock pulses
        o_os_tick   <= 1'b0;
        o_baud_tick <= 1'b0;

        if(r_os_cnt == OS_DIV-1) begin
            r_os_cnt  <= {OS_CNT_WIDTH{1'b0}};
            o_os_tick <= 1'b1;

            // One baud_tick for every 16 os_tick periods
            if(r_baud_cnt == 4'd15) begin
                r_baud_cnt  <= 4'd0;
                o_baud_tick <= 1'b1;
            end
            else begin
                r_baud_cnt <= r_baud_cnt + 1'b1;
            end
        end
        else begin
            r_os_cnt <= r_os_cnt + 1'b1;
        end
    end
end

endmodule
