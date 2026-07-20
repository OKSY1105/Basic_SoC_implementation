`timescale 1ns / 1ps

module fsm(

i_clk,
i_areset,
i_in,
o_fsm

);
input i_clk, i_areset, i_in;
output o_fsm;
reg o_fsm;


always @(posedge i_clk, posedge i_areset) begin
	if(i_areset) begin
	
		o_fsm <=0;
	end

	else begin 
		case(i_in)
			1'b1 : o_fsm<= ~o_fsm;
			1'b0: o_fsm<= o_fsm;
			
		endcase
	end
end

endmodule
