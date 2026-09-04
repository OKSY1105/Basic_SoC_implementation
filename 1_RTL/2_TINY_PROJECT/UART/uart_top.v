module uart_top #(
	parameter CLK_FREQ_HZ = 100_000_000,
	parameter BAUD_RATE = 115200,
	parameter DATA_BIT =8,
	parameter FIFO_DEPTH =16
)(
	i_clk,
	i_rst_n,
	
	//UART input & output
	o_uart_txd,
	i_uart_rxd,

	//Transmit Holding Register(cpu is going to lose the data so THR need
	//to save)
	i_thr_we, // transmit write data enable
	i_thr_wdata,

	//Receive Holding Register(dosen't know when cpu will get data so RHR
	//need to save data)
	o_rhr_re, // read data enable
	o_rhr_rdata,

	//Line Status Register (tell to cpu uarts state)
	o_lsr_dr,   // rx fifp has read able data
	o_lsr_thre, // tx fifo is empty		
	o_lsr_temt, // tx fifo and tx shift register is empty(cpu need to know transmit data is over)
	o_lsr_fe, //didn't receive stop bit 
	o_lsr_pe, // parity bit is different
	o_lsr_oe, //  RX overrun error: new data was lost because RX FIFO was full(to tell cpu there was overflow)
	o_tx_fifo_full, // tx fifo is full
	o_rx_fifo_ful // rx fifo is full
);

input i_clk;
input i_rstn;
input i_uart_rxd;
input i_thr_we;
input [DATA_BIT-1:0] i_thr_wdata;

output o_uart_txd;
output o_rhr_re;
output [DATA_BIT-1:0] o_rhr_rdata;
output o_lsr_dr;
output o_lsr_thre;
output o_lsr_temt;
output o_lsr_fe, o_lsr_pe,o_lsr_oe;
output o_tx_fifo_full, o_rx_fifo_full;

wire w_os_tick;
wire w_baud_tick;


/*****************************
* Baud Rate Generator
***************************/
baud_rate_gen #(
	.CLK_FREQ_HZ(CLK_FRE_HZ),
	.BAUD_RATE(BAUD_RATE)
)
u_baud_rate_gen(
	.i_clk(i_clk),
	.i_rst_n(i_rst_n),
	.w_os_tick(w_os_tick),
	.w_baud_tick(w_baud_tick)
);


/*****************************
* UART TX
***************************/

uart_tx #(
	.DATA_BIT(DATA_BIT),
	.FIFO_DEPTH(FIFO_DEPTH)
)
u_uart_tx(
	.i_clk(i_ck),
	.i_rst_n(i_rst_n),

	.baud_tick(baud_tick),

	.o_uart_txd(o_uart_txd),
	
	.i_thr_we(i_thr_we),
	.i_rhr_wdata(i_thr_wdata),

	.o_tx_fifo_full(o_tx_fifo_full),
	
	.o_lsr_fe(o_lsr_fe),
	.o_lsr_pe(o_lsr_pe),
	.o_lsr_oe(o_lsr_oe),
);



/*****************************
* UART X
***************************/

uart_rx #(
        .DATA_BIT(DATA_BIT),
        .FIFO_DEPTH(FIFO_DEPTH)
)
u_uart_rx(
        .i_clk(i_ck),
        .i_rst_n(i_rst_n),

        .os_tick(os_tick),
        .i_uart_rxd(i_uart_rxd),

	.o_rhr_re(o_rhr_re),
        .o_rhr_rdata(o_thr_rdata),
       
       	.o_rx_fifo_full(o_rx_fifo_full),
	
	.o_lsr_dr(o_lsr_dr),
        .o_lsr_pe(o_lsr_pe),
	.o_lsr_oe(o_lsr_oe),
        .o_lsr_fe(o_lsr_fe)
);




endmodule
