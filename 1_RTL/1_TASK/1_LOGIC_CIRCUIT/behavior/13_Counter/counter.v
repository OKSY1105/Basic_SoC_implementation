`timescale 1ns / 1ps

module counter(

i_clk,
i_reset,
i_counter_down_start,
o_counter_up,
o_counter_down

);


input i_clk, i_reset;
input i_counter_down_start;
output o_counter_up;
output o_counter_down;

reg [3:0] o_counter_up;
reg [3:0] o_counter_down;

always @ (posedge i_clk, posedge i_reset ) begin
	if(i_reset) begin 
		o_counter_up <=0;
		o_counter_down <=0;
	end

	else if (i_counter_down_start)begin
		o_counter_down <=10;
	end

	else begin
		if(o_counter_down > 0 ) o_counter_down <= o_counter_down-1;
		else o_counter_down = o_counter_down;
	end


end

always @ (posedge i_clk, posedge i_reset ) begin
        if(i_reset) begin
                o_counter_up <=0;
                o_counter_down <=0;
        end

        else if (o_counter_up < 15)begin
                o_counter_up <=o_counter_up +1;
        end
	
	else o_counter_up <=0;
        

end

endmodule
