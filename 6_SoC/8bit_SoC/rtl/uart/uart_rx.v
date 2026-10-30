module uart_rx #(
    parameter DATA_BITS  = 8,
    parameter FIFO_DEPTH = 16
)(
    i_clk,
    i_rst_n,
    i_os_tick,
    w_uart_rxd,

    o_rhr_rdata,
    i_rhr_re,

    o_lsr_dr,
    o_lsr_fe,
    o_lsr_pe,
    o_rx_fifo_full,
    o_lsr_oe
);

input                       i_clk;
input                       i_rst_n;
input                       i_os_tick;
input                       w_uart_rxd;
input                       i_rhr_re;

output     [DATA_BITS-1:0]  o_rhr_rdata;
output                      o_lsr_dr;
output reg                  o_lsr_fe;
output reg                  o_lsr_pe;
output reg                  o_lsr_oe;
output                      o_rx_fifo_full;

localparam S_IDLE   = 3'd0;
localparam S_START  = 3'd1;
localparam S_DATA   = 3'd2;
localparam S_PARITY = 3'd3;
localparam S_STOP   = 3'd4;

reg [2:0] r_state;

/**********************
 * RX synchronizer + falling-edge detector
 **********************/
reg r_rxd_ff1;
reg r_rxd_ff2;
reg r_rxd_prev;

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        r_rxd_ff1  <= 1'b1;
        r_rxd_ff2  <= 1'b1;
        r_rxd_prev <= 1'b1;
    end
    else begin
        r_rxd_ff1  <= w_uart_rxd;
        r_rxd_ff2  <= r_rxd_ff1;
        r_rxd_prev <= r_rxd_ff2;
    end
end

wire w_falling_edge;
assign w_falling_edge = r_rxd_prev && !r_rxd_ff2;

/**********************
 * 16x oversampling
 **********************/
reg [3:0] r_os_cnt;
reg       r_sample7;
reg       r_sample8;
reg       r_sample9;

wire w_majority_bit;
assign w_majority_bit =
       (r_sample7 & r_sample8)
     | (r_sample7 & r_sample9)
     | (r_sample8 & r_sample9);

reg [DATA_BITS-1:0] r_rx_shift;
reg [2:0]           r_bit_cnt;

/**********************
 * RX FIFO
 **********************/
reg  r_fifo_w_en;
wire w_fifo_empty;

fifo #(
    .WIDTH(DATA_BITS),
    .DEPTH(FIFO_DEPTH)
)
u_rx_fifo(
    .i_clk   (i_clk),
    .i_rst_n (i_rst_n),

    .i_w_en  (r_fifo_w_en),
    .i_w_data(r_rx_shift),

    .i_r_en  (i_rhr_re),
    .o_r_data(o_rhr_rdata),

    .o_full  (o_rx_fifo_full),
    .o_empty (w_fifo_empty)
);

// DR = RX FIFO has at least one valid byte
assign o_lsr_dr = !w_fifo_empty;

/**********************
 * RX FSM
 **********************/
always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        r_state     <= S_IDLE;
        r_os_cnt    <= 4'd0;

        r_sample7   <= 1'b0;
        r_sample8   <= 1'b0;
        r_sample9   <= 1'b0;

        r_rx_shift  <= {DATA_BITS{1'b0}};
        r_bit_cnt   <= 3'd0;
        r_fifo_w_en <= 1'b0;

        o_lsr_fe    <= 1'b0;
        o_lsr_pe    <= 1'b0;
        o_lsr_oe    <= 1'b0;
    end
    else begin
        // RX FIFO write enable is a one-clock pulse
        r_fifo_w_en <= 1'b0;

        case(r_state)
            S_IDLE: begin
                // UART idle=1, start bit begins with 1->0
                if(w_falling_edge) begin
                    r_os_cnt <= 4'd0;
                    r_state  <= S_START;
                end
            end

            S_START: begin
                if(i_os_tick) begin
                    if(r_os_cnt == 4'd7)
                        r_sample7 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd8)
                        r_sample8 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd9)
                        r_sample9 <= r_rxd_ff2;

                    if(r_os_cnt == 4'd15) begin
                        r_os_cnt <= 4'd0;

                        // Valid start bit must be 0
                        if(w_majority_bit == 1'b0) begin
                            r_bit_cnt <= 3'd0;
                            r_state   <= S_DATA;
                        end
                        else begin
                            r_state <= S_IDLE;
                        end
                    end
                    else begin
                        r_os_cnt <= r_os_cnt + 1'b1;
                    end
                end
            end

            S_DATA: begin
                if(i_os_tick) begin
                    if(r_os_cnt == 4'd7)
                        r_sample7 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd8)
                        r_sample8 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd9)
                        r_sample9 <= r_rxd_ff2;

                    if(r_os_cnt == 4'd15) begin
                        r_os_cnt <= 4'd0;

                        // UART receives LSB first: D0 -> D7
                        r_rx_shift[r_bit_cnt] <= w_majority_bit;

                        if(r_bit_cnt == DATA_BITS-1) begin
                            r_bit_cnt <= 3'd0;
                            r_state   <= S_PARITY;
                        end
                        else begin
                            r_bit_cnt <= r_bit_cnt + 1'b1;
                        end
                    end
                    else begin
                        r_os_cnt <= r_os_cnt + 1'b1;
                    end
                end
            end

            S_PARITY: begin
                if(i_os_tick) begin
                    if(r_os_cnt == 4'd7)
                        r_sample7 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd8)
                        r_sample8 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd9)
                        r_sample9 <= r_rxd_ff2;

                    if(r_os_cnt == 4'd15) begin
                        r_os_cnt <= 4'd0;

                        // Even parity: expected parity bit = XOR of received data bits
                        if(w_majority_bit != (^r_rx_shift))
                            o_lsr_pe <= 1'b1;

                        r_state <= S_STOP;
                    end
                    else begin
                        r_os_cnt <= r_os_cnt + 1'b1;
                    end
                end
            end

            S_STOP: begin
                if(i_os_tick) begin
                    if(r_os_cnt == 4'd7)
                        r_sample7 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd8)
                        r_sample8 <= r_rxd_ff2;
                    if(r_os_cnt == 4'd9)
                        r_sample9 <= r_rxd_ff2;

                    if(r_os_cnt == 4'd15) begin
                        r_os_cnt <= 4'd0;

                        // Stop bit must be 1
                        if(w_majority_bit != 1'b1)
                            o_lsr_fe <= 1'b1;

                        // Store completed byte in RX FIFO
                        if(!o_rx_fifo_full) begin
                            r_fifo_w_en <= 1'b1;
                        end
                        else begin
                            // New byte could not be stored
                            o_lsr_oe <= 1'b1;
                        end

                        r_state <= S_IDLE;
                    end
                    else begin
                        r_os_cnt <= r_os_cnt + 1'b1;
                    end
                end
            end

            default: begin
                r_state <= S_IDLE;
            end
        endcase
    end
end

endmodule
