module fidivider #(parameter DIVISOR = 10) 
(

 i_clk_in,
 i_rstn,
 o_clk_out


); localparam WIDTH = $clog2(DIVISOR);


	input i_clk_in;
	input i_rstn;
	output o_clk_out;

	reg [WIDTH-1:0] r_cnt;
	reg o_clk_out;

always @(posedge i_clk_in) begin
	if(!i_rstn)begin
		
		r_cnt<=0;
		o_clk_out <=0;

	end

	else begin
        	if (r_cnt == (DIVISOR / 2 - 1)) begin
        	        o_clk_out <= ~o_clk_out; 
			r_cnt <=0;
		end

		else begin
			r_cnt<=r_cnt+1;
		end
	end

end



endmodule
