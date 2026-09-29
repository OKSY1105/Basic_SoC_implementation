module tb_FSM;

reg i_clk;
reg i_rstn;
reg i_din_bit;

wire o_dout_bit;

FSM DUT(

.i_clk(i_clk),
.i_rstn(i_rstn),
.i_din_bit(i_din_bit),

.o_dout_bit(o_dout_bit)


);

always #5 i_clk =~i_clk;


initial begin

i_clk =0;
i_rstn =0;
i_din_bit =0;

#100 i_rstn =1;
   #10 i_din_bit = 1'b0;
    #10 i_din_bit = 1'b0;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b0;
    #10 i_din_bit = 1'b0;
    #10 i_din_bit = 1'b0;
    #10 i_din_bit = 1'b0;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b1;
    #10 i_din_bit = 1'b0;
    #100 i_rstn = 1'b0;
    #2000 $finish;



/*repeat (5)begin 
	@(posedge i_clk);

	i_din_bit <=$random%2;
	end

#20 $finish;
*/
end



endmodule
