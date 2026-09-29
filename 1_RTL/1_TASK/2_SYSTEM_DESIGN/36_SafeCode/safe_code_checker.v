`timescale 1ns/ 1ps
module safe_code_checker (
	i_clk,
	i_rst,
	i_digit_in,
	i_code_in,
	o_match
);
input i_clk, i_rst;
input [2:0] i_digit_in;
input [11:0] i_code_in;
output o_match;

reg [2:0] w_check;
reg [1:0] r_current_state;
reg [1:0] w_next_state;
reg r_match;

localparam S_DIGIT0 = 2'b00;
localparam S_DIGIT1 = 2'b01;
localparam S_DIGIT2 = 2'b10;
localparam S_DIGIT3 = 2'b11;

always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_current_state <= S_DIGIT0;
            r_match         <= 1'b0;
        end 
	
	else begin
            r_current_state <= w_next_state;
            
            
            if ((r_current_state == S_DIGIT3) && (w_check == 3'd0))
                r_match <= 1'b1;
            else
                r_match <= 1'b0;
        end
end

always @(*) begin
        
        w_next_state = r_current_state;
        w_check      = 3'b111;

        case (r_current_state)
            S_DIGIT0: begin
                w_check = i_code_in[11:9] ^ i_digit_in; 
                if (w_check == 3'd0)
                    w_next_state = S_DIGIT1;
                else
                    w_next_state = S_DIGIT0;
            end

            S_DIGIT1: begin
                w_check = i_code_in[8:6] ^ i_digit_in;
                if (w_check == 3'd0)
                    w_next_state = S_DIGIT2;
                else
                    w_next_state = S_DIGIT0;
            end

            S_DIGIT2: begin
                w_check = i_code_in[5:3] ^ i_digit_in;
                if (w_check == 3'd0)
                    w_next_state = S_DIGIT3;
                else
                    w_next_state = S_DIGIT0;
            end

            S_DIGIT3: begin
                w_check = i_code_in[2:0] ^ i_digit_in;
                if (w_check == 3'd0)
                    w_next_state = S_DIGIT0; 
                else
                    w_next_state = S_DIGIT0;
            end

            default: begin
                w_next_state = S_DIGIT0;
                w_check      = 3'b111;
            end
        endcase
end

assign o_match = r_match;

endmodule
