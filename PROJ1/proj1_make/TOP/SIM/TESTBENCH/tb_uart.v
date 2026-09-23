`timescale 1ns/10ps

module tb_uart;

reg i_clk;
reg i_rst_n;
reg i_uart_rxd;

wire o_uart_txd;

`ifdef function_sim
initial begin
        $dumpfile ("DUMP/uart.vcd");
        $dumpvars(0,tb_uart) ;
end
`endif

/********************************
 * DUT
 ********************************/

uart_top u_uart_top (
    .i_clk          (i_clk),
    .i_rst_n        (i_rst_n),

    .o_uart_txd     (o_uart_txd),
    .i_uart_rxd     (i_uart_rxd),

    .i_thr_we       (1'b0),
    .i_thr_wdata    (8'h00),

    .o_rhr_re       (),
    .o_rhr_rdata    (),

    .o_lsr_dr       (),
    .o_lsr_thre     (),
    .o_lsr_temt     (),

    .o_lsr_fe       (),
    .o_lsr_pe       (),
    .o_lsr_oe       (),

    .o_tx_fifo_full (),
    .o_rx_fifo_full ()
);


/********************************
 * Clock
 ********************************/

always #5 i_clk = ~i_clk;


/********************************
 * PAD Test
 ********************************/

initial begin

    i_clk      = 1'b0;
    i_rst_n    = 1'b0;
    i_uart_rxd = 1'b1;

    #20;
    i_rst_n = 1'b1;


    // RX PAD TEST
    #20;
    i_uart_rxd = 1'b0;

    #20;
    i_uart_rxd = 1'b1;

    #20;
    i_uart_rxd = 1'b0;

    #20;
    i_uart_rxd = 1'b1;


    // TX PAD TEST
    #20;
    force u_uart_top.w_uart_txd = 1'b0;

    #20;
    force u_uart_top.w_uart_txd = 1'b1;

    #20;
    force u_uart_top.w_uart_txd = 1'b0;

    #20;
    force u_uart_top.w_uart_txd = 1'b1;

    #20;
    release u_uart_top.w_uart_txd;


    #20;
    $finish;

end

endmodule
