module uart_tx #(
    parameter DATA_BIT   = 8,
    parameter FIFO_DEPTH = 16
)(
    i_clk,
    i_rst_n,
    w_baud_tick,

    o_uart_txd,
    i_thr_we,
    i_thr_wdata,
    o_tx_fifo_full,
    o_lsr_thre,
    o_lsr_temt
);

/**********************
 * CPU to TX
 **********************/
input                       i_clk;
input                       i_rst_n;
input                       w_baud_tick;
input                       i_thr_we;
input      [DATA_BIT-1:0]   i_thr_wdata;

output reg                  o_uart_txd;

/**********************
 * TX status to CPU
 **********************/
output                      o_tx_fifo_full;
output                      o_lsr_thre;
output                      o_lsr_temt;

localparam S_IDLE   = 3'd0;
localparam S_START  = 3'd1;
localparam S_DATA   = 3'd2;
localparam S_PARITY = 3'd3;
localparam S_STOP   = 3'd4;

reg [2:0] r_state;

reg [DATA_BIT-1:0] r_tx_shift;
reg [2:0]          r_bit_cnt;
reg                r_parity_bit;

wire                       w_fifo_empty;
wire [DATA_BIT-1:0]        w_fifo_rdata;
reg                        r_fifo_rd_en;

/**********************
 * TX FIFO
 **********************/
fifo #(
    .WIDTH(DATA_BIT),
    .DEPTH(FIFO_DEPTH)
)
u_tx_fifo(
    .i_clk   (i_clk),
    .i_rst_n (i_rst_n),

    .i_w_en  (i_thr_we),
    .i_w_data(i_thr_wdata),

    .i_r_en  (r_fifo_rd_en),
    .o_r_data(w_fifo_rdata),

    .o_full  (o_tx_fifo_full),
    .o_empty (w_fifo_empty)
);

// THRE = TX FIFO empty
assign o_lsr_thre = w_fifo_empty;

// TEMT = TX FIFO empty AND TX engine idle
assign o_lsr_temt = w_fifo_empty && (r_state == S_IDLE);

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        r_state        <= S_IDLE;
        o_uart_txd     <= 1'b1; // UART idle = 1
        r_fifo_rd_en   <= 1'b0;
        r_tx_shift     <= {DATA_BIT{1'b0}};
        r_bit_cnt      <= 3'd0;
        r_parity_bit   <= 1'b0;
    end
    else begin
        // FIFO read enable is a one-clock pulse
        r_fifo_rd_en <= 1'b0;

        case(r_state)
            S_IDLE: begin
                o_uart_txd <= 1'b1;

                // If TX FIFO has at least one byte, load it into TX shift register
                if(!w_fifo_empty) begin
                    r_fifo_rd_en <= 1'b1;
                    r_tx_shift   <= w_fifo_rdata;
                    r_parity_bit <= ^w_fifo_rdata; // even parity bit
                    r_state      <= S_START;
                end
            end

            S_START: begin
                if(w_baud_tick) begin
                    o_uart_txd <= 1'b0;
                    r_bit_cnt  <= 3'd0;
                    r_state    <= S_DATA;
                end
            end

            S_DATA: begin
                if(w_baud_tick) begin
                    o_uart_txd <= r_tx_shift[0];
                    r_tx_shift <= r_tx_shift >> 1;

                    if(r_bit_cnt == DATA_BIT-1) begin
                        r_state <= S_PARITY;
                    end
                    else begin
                        r_bit_cnt <= r_bit_cnt + 1'b1;
                    end
                end
            end

            S_PARITY: begin
                if(w_baud_tick) begin
                    o_uart_txd <= r_parity_bit;
                    r_state    <= S_STOP;
                end
            end

            S_STOP: begin
                if(w_baud_tick) begin
                    o_uart_txd <= 1'b1;
                    r_state    <= S_IDLE;
                end
            end

            default: begin
                r_state <= S_IDLE;
            end
        endcase
    end
end

endmodule
