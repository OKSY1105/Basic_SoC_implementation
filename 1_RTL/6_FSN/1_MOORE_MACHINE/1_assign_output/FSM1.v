module FSM1(
i_clk,
i_rstn,
i_go,
i_we,
o_rd,
o_ds
);


input i_clk;
input i_rstn;
input i_go;
input i_we;
output o_rd;
output o_ds;

parameter IDLE = 2'b00;
parameter READ = 2'b01;
parameter DLY = 2'b11;
parameter DONE = 2'b10;

reg [1:0] state;
reg [1:0] next;

//1. next state logic
always @(posedge i_clk, negedge i_rstn) begin
	next = 2'bx;
	
	case(state)
	 IDLE : if(i_go) next =READ;
		else next = IDLE;
	 
	 READ : next = DLY; 

	 DLY : if(i_we) next = READ;
	       else next = DONE;

	 DONE : next = IDLE;
	
	endcase

end

//2. current state logic
always @(posedge i_clk, negedge i_rstn) begin
        if(!i_rstn) state <=IDLE;
        else state <= next;


end

// 3.output logic (data flow modeling)
assign rd = (state == READ) || (state ==DLY);
assign ds = (state ==DONE);



endmodule
