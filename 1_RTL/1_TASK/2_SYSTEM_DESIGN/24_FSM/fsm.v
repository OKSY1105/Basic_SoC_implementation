`timescale 1ns / 1ps
module fsm(

i_clk,
i_reset,
i_in,
o_out

);
input i_clk, i_reset, i_in;
output o_out;

reg o_out;
reg [1:0] r_state, r_next_state;  



always @(posedge i_clk or posedge i_reset) begin
	 
	if(i_reset) begin
		r_state <=2'b00;
		o_out <=0;
	end

	else r_state <= r_next_state;

end

always @(*) begin
	case(r_state)
		2'b00: r_next_state = i_in ? 2'b01 : 2'b00; 
		2'b01: r_next_state = i_in ? 2'b10 : 2'b00;
		2'b10: begin
			if(i_in) o_out=i_in;
			else begin
				o_out =i_in;
				r_next_state = 2'b00;
			end
		end
		default: o_out =1'bx;
	endcase
end


endmodule

