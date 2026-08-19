`timescale 1ns / 1ps 

/*module interrupt_ctrl#(
parameter INT_COUNT =8
)(

i_clk,
i_rst_n,
i_interrupt_req,
i_interrupt_ack,
o_interrupt_service,
o_interrupt_active

);
input i_clk, i_rst_n;
input [INT_COUNT-1 : 0] i_interrupt_req;
input i_interrupt_ack;
output [INT_COUNT-1 : 0] o_interrupt_service;
output o_interrupt_active;

reg [INT_COUNT-1 : 0] o_interrupt_service;
reg o_interrupt_active;


reg [INT_COUNT-1:0] r_masking;
wire [INT_COUNT-1:0] masked_req = i_interrupt_req & ~(r_masking);
wire w_req = (|masked_req); 

integer i;
    // 우선순위 인코더
    function [$clog2(INT_COUNT)-1:0] priority_encoder;
        input [INT_COUNT-1:0] requests;
        reg [$clog2(INT_COUNT)-1:0] result;
        reg found;
        begin
            result = 0;
            found = 0;
            for (i = INT_COUNT-1; i >= 0; i = i - 1) begin
                if (requests[i] && !found) begin
                    result = i;
                    found = 1;
                end
            end
            priority_encoder = result;
        end
    endfunction


    always @(posedge i_clk or negedge i_rst_n)begin
	    if(!i_rst_n) begin
		    o_interrupt_service <={INT_COUNT{1'b0}};
		    o_interrupt_active <=1'd0;
		    r_masking <= {INT_COUNT{1'b0}}; 
	    end

	    else begin
		   case ({o_interrupt_active, i_interrupt_ack})
			   2'b00: begin

				   if (w_req) begin 
					   o_interrupt_active  <= 1'b1;
                                   	   o_interrupt_service <= (1 << priority_encoder(masked_req));
                    		   end
                    		   
				   else begin
                        		   o_interrupt_service <= {INT_COUNT{1'b0}};
                        		   o_interrupt_active  <= 1'b0;
                    		   end
                	   end

                
                	   2'b01: begin
                    		  o_interrupt_service <= {INT_COUNT{1'b0}};
                    		  o_interrupt_active  <= 1'b0;
                	   end

                // [CASE 3] 2'b10 : 현재 서비스 처리 중 (ACK 기다리는 중) -> 상태 유지 (LOCK)
                	   2'b10: begin
                    		o_interrupt_service <= o_interrupt_service;
                    		o_interrupt_active  <= o_interrupt_active;
                	   end

                // [CASE 4] 2'b11 : 서비스 처리 완료! (ACK 수신) -> 마스크 누적 및 클리어
                	   2'b11: begin
                    //  핵심: 방금 끝난 o_interrupt_service 비트를 마스크에 누적!
                    		r_masking           <= (r_masking | o_interrupt_service);
                    		o_interrupt_service <= {INT_COUNT{1'b0}};
                    		o_interrupt_active  <= 1'b0;
                	   end
            endcase

	    end
    end

endmodule
*/


module interrupt_ctrl #(
	parameter INT_COUNT = 8
)(
	i_clk,
	i_rst_n,
	i_interrupt_req,
	i_interrupt_ack,
	o_interrupt_service,
	o_interrupt_active
);

input i_clk, i_rst_n;
input [INT_COUNT-1:0] i_interrupt_req;
input i_interrupt_ack;
output [INT_COUNT-1:0] o_interrupt_service;
output o_interrupt_active;

reg [INT_COUNT-1:0] o_interrupt_service;
reg o_interrupt_active;


integer i;

	function integer clog2;
	       input integer INT_COUNT;
	       integer N;
	       begin
		       N= INT_COUNT -1;
		       for(clog2=0; N > 0; clog2 = clog2+1) begin
				N = N>>1;
			end
		end
	endfunction


	function [clog2(INT_COUNT)-1:0] msb;
		input [(INT_COUNT)-1:0] in_data;
		reg [clog2(INT_COUNT)-1:0] bit_find;
		reg found;
		begin
			bit_find =0;
			found =0;
			
			for (i =INT_COUNT-1; i >= 0; i=i-1) begin
				if(in_data[i] && !found) begin
					bit_find =i;
					found =1;
				end
			end
			
			msb = bit_find;
		end
	endfunction

reg [INT_COUNT-1 :0] r_mask;
wire [INT_COUNT-1:0] w_masked_req = i_interrupt_req & ~(r_mask);
always @ (posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		o_interrupt_service <={INT_COUNT{1'b0}};
		o_interrupt_active <=1'b0;
		r_mask <= {INT_COUNT{1'b0}};
	end

	else begin
	
		case(o_interrupt_active) 
			
			1'b0: if(w_masked_req !=0) begin
				o_interrupt_service <= (1<<msb(w_masked_req));
				o_interrupt_active <=1'b1;
			end
			else begin
				o_interrupt_service <= {INT_COUNT{1'b0}};
				o_interrupt_active <= 1'b0;
			end
			1'b1: if(i_interrupt_ack) begin
				r_mask <= r_mask | o_interrupt_service;
				o_interrupt_service <= {INT_COUNT{1'b0}};
                                o_interrupt_active <= 1'b0;
			end
			else begin
				o_interrupt_service <= o_interrupt_service;
                                o_interrupt_active <= 1'b1;

			end
			
		endcase

	end
end
endmodule
