`timescale 1ns / 1ps
module counter(
i_clk,
i_reset,
i_time_val,
i_cnt_en,
o_cnt,
o_decade,
o_en_cnt,
o_time_en,
o_time_cnt,
o_clock_h,
o_clock_m,
o_clock_s
);
    input            i_clk;
    input            i_reset;
    input      [7:0] i_time_val;
    input            i_cnt_en;
    output     [7:0] o_cnt;
    output     [7:0] o_decade;   
    output     [7:0] o_en_cnt;   
    output           o_time_en;   
    output     [7:0] o_time_cnt;   
    output     [4:0] o_clock_h;  
    output     [5:0] o_clock_m;   
    output     [5:0] o_clock_s;
    reg [7:0] o_cnt;
    reg [7:0] o_decade;
    reg [7:0] o_en_cnt;
    reg [7:0] o_time_cnt;
    reg [4:0] o_clock_h;
    reg [5:0] o_clock_m;
    reg [5:0] o_clock_s;

    always@(posedge i_clk or posedge i_reset) begin
	    if(i_reset) o_cnt<=8'h00;
	    else o_cnt<= o_cnt+1;
    end

    always@(posedge i_clk or posedge i_reset) begin

            if(i_reset) o_decade<=8'h00;

	    else begin
		    case(o_decade[3:0])
			    4'd9 : begin
				    o_decade[3:0] <=0;
				    
				    case(o_decade[7:4])
					    4'd9 : o_decade[7:4] <=0;
					    default : o_decade[7:4] <= o_decade[7:4]+1;
				   endcase
			   end

			   default : o_decade[3:0] <= o_decade[3:0]+1;
		   endcase
		    
		    
	    end
    end

    always@(posedge i_clk or posedge i_reset)begin
	   if(i_reset) o_en_cnt<=8'h00;
	   else begin
		   if(i_cnt_en) o_en_cnt <= o_en_cnt+1;
	   	   else o_en_cnt <= o_en_cnt; 
	   end
    end

    assign o_time_en = (o_time_cnt == i_time_val) ? 1'b1 : 1'b0; 
    always@(posedge i_clk or posedge i_reset)begin
	    if(i_reset)begin
		    o_time_cnt <= 8'h00;
		   
	    end
	   
	   else begin
		   if(o_time_cnt == i_time_val) begin
			  o_time_cnt<=8'h00;
		   end

		   else begin
			   
			   o_time_cnt <= o_time_cnt+ 1'b1;
		   end
	   
	   
	   end

           
    end
    
    wire w_max_sec =(o_clock_s ==59);
    wire w_max_min = (o_clock_m == 59) && w_max_sec;
    wire w_max_hour = (o_clock_h == 23) && w_max_min;  

    always@(posedge i_clk or posedge i_reset)begin
	    if(i_reset) begin
		   o_clock_s <= 6'd0;
		   o_clock_m <= 6'd0;
		   o_clock_h <= 5'd0;
	   end

           else begin
                   if(w_max_sec) o_clock_s <=6'd0;
		   else o_clock_s <= o_clock_s+1'b1;

		   if(w_max_min) o_clock_m <=6'd0;
                   else if(w_max_sec) o_clock_m <= o_clock_m+1'b1;

		   if(w_max_hour) o_clock_h <=0;
                   else if(w_max_min) o_clock_h <= o_clock_h+1'b1;

                   




           end


    end



endmodule
