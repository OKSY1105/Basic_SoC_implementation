`timescale 1ns / 1ps 

module interrupt_crtl #(
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


    always @(posedge i_clk)begin
	    if(!i_rst_n) o_interrupt_service <=0;

	    else begin
		    if(i_interrupt_ack) begin
			    o_interrupt_service <=0;
			    o_interrupt_active <=0;
		    end

		    else if(o_interrupt_active) o_interrupt_service <= priority_encoder(i_interrupt_req);


	    end
    end

endmodule


