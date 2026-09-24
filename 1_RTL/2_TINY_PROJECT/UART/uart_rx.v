module uart_rx #(
	parameter DATA_BITS =8,
	parameter FIFO_DEPTH =16
)(
	i_clk,
	i_rst_n,
	i_os_tick, // baudrate /16 
	w_uart_rxd, //data from uart_top
	o_rhr_rdata, // data _output
	i_rhr_re, // data read enable
	o_lsr_dr, // data is ready (rx_fifo has at least 1 data)
	o_lsr_fe, // there was no stop bit
	o_lsr_pe, // parity bit is worng
	o_rx_fifo_full, //rx_fifo is full but not data loss
	o_lsr_oe // ther (was/is) data loss when rx_fifo (was/is) full
);

input i_clk;
input i_rst_n;
input i_os_tick;
input w_uart_rxd;

input i_rhr_re;

output [7:0] o_rhr_rdata;
output o_lsr_dr;
output o_lsr_fe;
output o_lsr_pe;
output o_lsr_oe;

reg o_lsr_fe;
reg o_lsr_pe;
reg o_lsr_oe;


localparam S_IDLE   = 3'd0;
localparam S_START  = 3'd1;
localparam S_DATA   = 3'd2;
localparam S_PARITY = 3'd3;
localparam S_STOP   = 3'd4;

reg [2:0] state;

reg r_rxd_ff1;  // 비동기화된 RX값
reg r_rxd_ff2;  // 현재 동기화된 RX 값
reg r_rxd_prev; // 한 클럭 전 RX 값

always(posedge i_clk or negedge i_rst_n)begin
	if(i_rst_n) begin
		r_rxd_ff1  <=1'b1;
		r_rxd_ff2  <=1'b1;
		r_rxd_prev <=1'b1;
	end

	else begin
		r_rxd_ff1  <=w_uart_rxd;
		r_rxd_ff2  <=r_rxd_ff1;
		r_rxd_prev <=r_rxd_ff2;
	end
end

wire falling_edge;
assign fallin_edge = r_rxd_prev & !(r_rxd_ff2);

reg [3:0] r_os_cnt;

reg sample7;
reg sample8;
reg sample9;

assign majority_bit =
       (sample7 & sample8)
     | (sample7 & sample9)
     | (sample8 & sample9);

reg [DATA_BIT-1:0] r_rx_shift;
reg [2:0]	   r_bit_cnt;

reg r_fifo_w_en;
reg r_fifo_rx_empty;

fifo #(
	.WIDTH(DATA_BITS),
	.DEPTH(FIFO_DEPTH)
)
u_rx_fifo(
	.i_clk(i_clk),
	.i_rst_n(i_rst_n),

	.i_w_en(r_fifo_w_en),
	.o_w_data(o_rhr_rdata),

	.o_full(o_fifo_rx_full),
	.o_empty(r_fifo_rx_empty)
);
assign o_lsr_dr = !o_fifo_rx_empty;

always @(posedge i_clk or negedge i_rst_n) begin
	if(i_rst_n) begin
		state       <= S_IDLE;
		r_os_cnt    <=0;

		sample7     <=0;
		sample8     <=0;
		sample9     <=0;
		r_rx_shift  <=0;
	        r_bit_cnt   <=0;
		
		r_fifo_w_en <=0;

		o_lsr_fe    <=0;
		o_lsr_pe    <=0;
		o_lsr_oe    <=0;

	end

	else begin
		r_fifo_w_en <=0;

		case(state) begin
			S_IDLE : begin
				if(falling_edge)begin
					r_os_cnt <= 0;
					state <= S_IDLE;
				end
			end


		end
end	







