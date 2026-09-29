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
input 		i_clk;
input 		i_rst_n;
input 		i_thr_we; //write enable
input   [7:0] 	i_thr_wdata; // cpu is sending data to IO through Tx => in Tx sight data is given from cpu so input
input 		i_baud_tick; // clk to baudrate
	
output 		o_uart_txd; //to IO
reg 		o_uart_txd;
/*********************
 * to cpu
 *********************/
output 		o_tx_fifo_full; // fifo is full
output 		o_lsr_thre; //fifo is empty so can recive data
output 		o_lsr_temt; //shift & fifo is empty

localparam S_IDLE   = 3'd0;
localparam S_START  = 3'd1;
localparam S_DATA   = 3'd2;
localparam S_PARITY = 3'd3;
localparam S_STOP   = 3'd4;

reg   [2:0]     r_state;

reg   [7:0]	r_tx_shift;
reg   [2:0]	r_bit_cnt;
reg		r_parity_bit;

wire		w_fifo_empty;
wire    [7:0]	w_fifo_rdata;
reg		r_fifo_rd_en;

fifo #(
	.WIDTH(DATA_BIT),
	.DEPTH(FIFO_DEPTH)
)
u_tx_fifo(
	.i_clk(i_clk),
	.i_rst_n(i_rst_n),
	
	.i_we_en(i_thr_we),
	.i_wdata(i_thr_wdata),

	.o_re_en(r_fifo_rd_en),
	.o_fifo_rdata(w_fifo_rdata),

	.o_fifo_full(o_tx_fifo_full),
	.o_fifo_empty(w_fifo_empty)
);

assign o_lsr_thre = o_tx_fifo_full;

assign o_lsr_temt = o_lsr_thre &&(r_state == S_IDLE); //


always @(posedge i_clk or negedge i_rst_n) begin
	
	if(!i_rst_n) begin
		r_state <= S_IDLE;
		o_uart_txd <=0;
		r_fifo_rd_en <=0;
		r_tx_shift <=0;
		r_bit_cnt <=0;
		r_parity_bit <=0;
	end

	else begin
		r_fifo_rd_en <=0;

		case(r_state)
			S_IDLE : begin
				
				o_uart_txd <=1'b1;
				
				if(!w_fifo_empty) begin
					r_fifo_rd_en <=1;
					r_tx_shift <= w_fifo_rdata;
					r_parity_bit <= ^w_fifo_rdata;
					r_state <= S_STAR;
				end
			end
			
			S_STAR : begin
				
				if(i_baud_tick)begin
				       o_uart_txd <=1'b0;
				       r_bit_cnt <=0;
			       	       r_state <= S_DATA;
			       end	       
		       end

		       S_DATA : begin 

		       		if(i_baud_tick) begin
					o_uart_txd <= r_tx_shift[0];
					r_tx_shift <= r_tx_shift >> 1;

					if(r_bit_cnt == DATA_BIT-1)begin
						r_state <= S_PARITY;
					end

					else begin
						r_bit_cnt <= r_bit_cnt +1'b1;
					end
				end
			end

			S_PARITY : begin
				
				if(i_baud_tick) begin
					o_uart_txd <= r_parity_bit;
					r_state <= S_STOP;
				end
			end
			
			S_STOP : begin
				if(i_baud_tick) begin
					o_uart_txd <=1'b1;
					r_state <= S_IDLE;
				end
			end

			default : begin
				r_state <= S_IDLE;
			end


		endcase

	end

end

endmodule
