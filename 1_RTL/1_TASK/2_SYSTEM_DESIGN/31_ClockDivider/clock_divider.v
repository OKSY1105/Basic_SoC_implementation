`timescale 1ns / 1ps
module clock_divider #(
	parameter INPUT_FREQ = 100_000_000,
	parameter OUTPUT_FREQ = 25_000_000
)( 
	i_clk,
	i_rst_n,
	o_clk
);
input i_clk, i_rst_n;
output o_clk;

reg o_clk;
reg [1:0] r_cnt;

always @ (posedge i_clk or negedge i_rst_n) begin

	if(!i_rst_n) begin
		o_clk <=1'b0;
		r_cnt <=2'b0;
		
	end

	else begin
		
		case({r_cnt,o_clk}) 
			3'b000 : begin
				o_clk <=1'b1;
				r_cnt <= 2'b01;
			end

			3'b011 : begin
				o_clk <=1'b1;
				r_cnt <= 2'b10;
			end

			3'b101 :begin
				o_clk <= 1'b0;
				r_cnt <=2'b11;
			end
			3'b110: begin
				o_clk <= 1'b0;
				r_cnt <= 2'b00;

			end
		endcase


	end


end
endmodule
