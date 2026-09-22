module uart_tx #(
	DATA_BIT = 8,
	FIFO_DEPTH =16	
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
 *  cpu to tx
**********************/
input i_clk;
input i_rst_n;
input i_thr_we;
input [7:0] i_thr_wdata; // cpu is sending data to IO through Tx => in Tx sight data is given from cpu so input
input w_baud_tick;
	
output o_uart_txd; //to IO

/*********************
 * to cpu
 *********************/
output o_tx_fifo_full; // fifo is full
output o_lsr_thre; //fifo is empty so can recive data
output o_lsr_temt; //shift & fifo is empty

localparam S_IDLE   = 3'd0;
localparam S_START  = 3'd1;
localparam S_DATA   = 3'd2;
localparam S_PARITY = 3'd3;
localparam S_STOP   = 3'd4;

reg [2:0] r_state;
reg [7:0] r_tx_shift;
reg 	  fifo_rd_en; //there is data in fifo


/********************************
*  fifo_tx
********************************/

fifo #(
	.WIDTH(DATA_BITS),
	.DEPTH(FIDO_DEPTH)
)
u_tx_fifo(
	.i_clk(i_clk),

always @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n)


end


endmodule
