module FSM(

i_clk,
i_rstn,
i_din_bit,
o_dout_bit

);

input i_clk;
input i_rstn;
input i_din_bit;
output o_dout_bit;


parameter START = 3'b000;
parameter RD0_ONCE = 3'b001;
parameter RD0_TWICE = 3'b011;
parameter RD1_ONCE = 3'b111;
parameter RD1_TWICE = 3'b110;

reg [2:0] next;
reg [2:0] state;

always @(state, i_din_bit) begin

		
	case(state)
		START : if(i_din_bit ==1) next = RD1_ONCE;
			else if( i_din_bit ==0) next = RD0_ONCE;
			else next = START;

		RD0_ONCE : if(i_din_bit ==1) next= RD1_ONCE;
			else if(i_din_bit==0) next = RD0_TWICE;
			else next = START;
			
		RD0_TWICE : if (i_din_bit ==1) next = RD1_ONCE;
			else if( i_din_bit ==0) next = RD0_TWICE;
			else next = START;

		RD1_ONCE : if (i_din_bit ==1) next = RD1_TWICE;
			else if(i_din_bit ==0) next = RD0_ONCE;
			else next = START;

		RD1_TWICE : if(i_din_bit == 1)  next =RD1_TWICE;
			else if(i_din_bit ==0) next =RD0_ONCE;
			else next = START;
		
		default : next = START;
		
	endcase 
		

end


always @(posedge i_clk,negedge i_rstn) begin 
	if(!i_rstn) begin

		state <= START;
	end

	else begin
		state <= next;
	end


end

assign o_dout_bit =((state == RD0_TWICE) && (i_din_bit == 0)) || 
                    ((state == RD1_TWICE) && (i_din_bit == 1)) ? 1 : 0 ;


endmodule 
