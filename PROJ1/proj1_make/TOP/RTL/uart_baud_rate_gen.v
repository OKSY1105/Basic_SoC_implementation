module baud_rate_gen #(
	parameter CLK_FREQ_HZ = 100_000_000,
	parameter BAUD_RATE = 115200
)(
	i_clk,
	i_rst_n,
	w_os_tick,
	w_baud_tick
);

input i_clk, i_rst_n;

output w_os_tick;
output w_baud_tick;

reg w_os_tick;
reg w_baud_tick;

localparam OS_DIV = CLK_FRQ_HZ/(BAUD_RATE * 16);
localparam OS_CNT = $clog2(OS_DIV);

reg [OS_CNT-1:0] os_cnt;
reg [3:0] baud_cnt;

/***************************
   *16x oversampling tick
****************************/

always@(posedge i_clk or negedge i_rst_n)begin
	if(!i_rst_n) begin
		w_os_tick <=1'b0;
		os_cnt <=0;
	end
	else begin
		w_os_tick <=1'b0;
		if(os_cnt == OS_DIV-1)begin
		       os_cnt <=0;
		       w_os_tick <=1'b1;
	       end

	       else os_cnt <= os_cnt+1;

	end
end


/***************************
   *baud_rate tick
****************************/
always@(posedge i_clk or negedge i_rst_n)begin
	if(!i_rst_n)begin
		w_baud_tick <=1'b0;
		baud_cnt <=4'd0;
	end
	
	else begin
		
		w_baud_tick <=0;
		
		if(w_os_tick ==1) begin
			if(baud_cnt == 15) begin
				baud_cnt <=0;
				w_baud_tick <=1;
			end

			else baud_cnt <= baud_cnt+1;
		end
	end
end


endmodule
