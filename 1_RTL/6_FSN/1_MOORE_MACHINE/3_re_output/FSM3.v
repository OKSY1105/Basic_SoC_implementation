module FSM3(

i_clk,
i_rstn,
i_go,
i_ws,
o_rd,
o_ds


);


input i_clk;
input i_rstn;
input i_go;
input i_ws;

output o_rd;
output o_ds;

parameter IDLE = 2'b00;
parameter READ = 2'b01;
parameter DLY = 2'b11;
parameter DONE = 2'b10;

reg [1:0] state;
reg [1:0] next;

reg o_rd;
reg o_ds;
 
always @ (posedge i_clk)begin

        next = 2'bx; 

        case(state)
        IDLE : if(i_go) next <= READ;
                else next<= IDLE;

        READ : next <=DLY;

        DLY : if(i_ws) next <= READ;
              else next<= DONE;
        
        DONE :  next <=IDLE;
                
        endcase

end

always @ (posedge i_clk)begin
        if(!i_rstn) state <= IDLE;
        else state <= next;
end



always @ (posedge i_clk)begin

        if(!i_rstn) begin 
		o_rd <= 1'b0;
		o_ds <= 1'b0;
	end


	else begin

	     case(next)
		
		READ : o_rd <=1'b1;
		DLY : o_rd <=1'b1;
		DONE : o_ds <=1'b1;

	     endcase	
	end
end

endmodule
