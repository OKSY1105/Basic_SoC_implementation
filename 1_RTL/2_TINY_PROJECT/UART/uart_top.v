module uart_top #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115200,
    parameter DATA_BIT    = 8,
    parameter FIFO_DEPTH  = 16
)(
    i_clk,
    i_rst_n,

    // UART physical pins
    o_uart_txd,
    i_uart_rxd,

    // THR interface : CPU -> UART TX
    i_thr_we,
    i_thr_wdata,

    // RHR interface : CPU <- UART RX
    i_rhr_re,
    o_rhr_rdata,

    // Line Status Register
    o_lsr_dr,
    o_lsr_thre,
    o_lsr_temt,
    o_lsr_fe,
    o_lsr_pe,
    o_lsr_oe,

    // Debug / verification
    o_tx_fifo_full,
    o_rx_fifo_full
);

input                       i_clk;
input                       i_rst_n;

output                      o_uart_txd;
input                       i_uart_rxd;

input                       i_thr_we;
input      [DATA_BIT-1:0]   i_thr_wdata;

input                       i_rhr_re;
output     [DATA_BIT-1:0]   o_rhr_rdata;

output                      o_lsr_dr;
output                      o_lsr_thre;
output                      o_lsr_temt;
output                      o_lsr_fe;
output                      o_lsr_pe;
output                      o_lsr_oe;

output                      o_tx_fifo_full;
output                      o_rx_fifo_full;


/************************************************
 * Internal signals
 ************************************************/
wire w_os_tick;
wire w_baud_tick;

wire w_uart_rxd;
wire w_uart_txd;


/************************************************
 * PAD connection
 *
 * Default simulation:
 *   external top pin <-> internal UART wire directly
 *
 * Real PAD cell simulation / implementation:
 *   compile with USE_IO_PAD defined and provide
 *   PADDI / PADDO library cells.
 ************************************************/
`ifdef USE_IO_PAD

PADDI u_pad_uart_rx (
    .PAD (i_uart_rxd),
    .Y   (w_uart_rxd)
);

PADDO u_pad_uart_tx (
    .PAD (o_uart_txd),
    .A   (w_uart_txd)
);

`else

assign w_uart_rxd = i_uart_rxd;
assign o_uart_txd = w_uart_txd;

`endif


/************************************************
 * Baud Rate Generator
 ************************************************/
baud_rate_gen #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .BAUD_RATE   (BAUD_RATE)
)
u_baud_rate_gen (
    .i_clk       (i_clk),
    .i_rst_n     (i_rst_n),

    .o_baud_tick (w_baud_tick),
    .o_os_tick   (w_os_tick)
);


/************************************************
 * UART TX
 ************************************************/
uart_tx #(
    .DATA_BIT   (DATA_BIT),
    .FIFO_DEPTH (FIFO_DEPTH)
)
u_uart_tx (
    .i_clk          (i_clk),
    .i_rst_n        (i_rst_n),

    .w_baud_tick    (w_baud_tick),

    .o_uart_txd     (w_uart_txd),

    .i_thr_we       (i_thr_we),
    .i_thr_wdata    (i_thr_wdata),

    .o_tx_fifo_full (o_tx_fifo_full),

    .o_lsr_thre     (o_lsr_thre),
    .o_lsr_temt     (o_lsr_temt)
);


/************************************************
 * UART RX
 ************************************************/
uart_rx #(
    .DATA_BITS  (DATA_BIT),
    .FIFO_DEPTH (FIFO_DEPTH)
)
u_uart_rx (
    .i_clk          (i_clk),
    .i_rst_n        (i_rst_n),

    .i_os_tick      (w_os_tick),
    .w_uart_rxd     (w_uart_rxd),

    .o_rhr_rdata    (o_rhr_rdata),
    .i_rhr_re       (i_rhr_re),

    .o_lsr_dr       (o_lsr_dr),
    .o_lsr_fe       (o_lsr_fe),
    .o_lsr_pe       (o_lsr_pe),
    .o_rx_fifo_full (o_rx_fifo_full),
    .o_lsr_oe       (o_lsr_oe)
);

endmodule
