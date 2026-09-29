`timescale 1ns / 1ps

// 1. L1_P1 parity ===========================================================
module parity_checker(
    input [7:0] data_in,  
    input    parity_bit,  
    output   parity_error
);

assign parity_error = ((^(data_in)) ^ parity_bit);

endmodule

// 2. L1_P6 FSM ===========================================================
module fsm(
    input wire clk,
    input wire reset,
    input wire in,
    output reg out
);

    parameter S0 = 2'b00; 
    parameter S1 = 2'b01; 
    parameter S2 = 2'b10; 

    reg [1:0] state, next_state;

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= S0;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        out = 1'b0;
        case (state)
            S0:    next_state = in ? S1 : S0;
            S1:    next_state = in ? S2 : S0;
            S2: begin
                if (in) begin
                    out = 1'b1;
		    next_state = S2;	      				    
                end
		else next_state = S0;
            end
        endcase
    end

endmodule


// 3. L1_P7 Counter(out_decade) ===========================================================
module counter(
    input       clk,
    input       areset,
    output reg [7:0] out_decade   
); 

    //decade count
    always @(posedge clk or posedge areset) begin
        if(areset) begin
            out_decade <= 8'h0;
        end
	
	else if(out_decade[3:0] == 4'd9 && out_decade[7:4] < 4'd9)  begin
            	out_decade[3:0] <= 4'd0; 
            	out_decade[7:4] <= out_decade[7:4] + 4'd1;

        end 
	
	else if(out_decade[7:0]== 8'h99 ) begin
        	out_decade[7:0] <= 8'h00;
		
        end
	
	else out_decade <= out_decade + 8'd1;

       		
	
    end

endmodule


// 4. L1_P8 bin2gray ===========================================================
module bin_2_gray #(
    parameter WIDTH = 4
)(
    input [WIDTH-1:0] binary_in,
    output [WIDTH-1:0] gray_out
);

genvar i;
generate
    for (i = 0; i < WIDTH; i = i + 1) begin : gen_gray
	    if (i == WIDTH-1) begin
		assign gray_out[i] = binary_in[i];
	    end
	    else  assign gray_out[i] = binary_in[i] ^ binary_in[i+1];
    end
endgenerate

endmodule

// 5. L1_P11 clock gating ===========================================================
module clock_gating(
   input wire clk_in,
    input wire rst_n,
    input wire enable,
    input wire [7:0] data_in,
    output reg [7:0] data_out
);

     wire gated_clk;

    assign gated_clk = clk_in & enable;
        
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'b0;
        end 
	else begin
		if(gated_clk) data_out <= data_in;
		else data_out<=data_out;
        end
    end

endmodule

// 6. L1_P12 interrupt_ctrl ===========================================================
module interrupt_ctrl #(
    parameter INT_COUNT = 8
)(
    input wire clk,
    input wire rst_n,
    input wire [INT_COUNT-1:0] interrupt_requests,
    input wire interrupt_ack,
    output reg [INT_COUNT-1:0] interrupt_service,
    output reg interrupt_active
);

    reg [INT_COUNT-1:0] interrupt_pending;
    reg [INT_COUNT-1:0] interrupt_mask;
    reg [$clog2(INT_COUNT)-1:0] current_interrupt;
    
    integer i;

    function [$clog2(INT_COUNT)-1:0] priority_encoder;
        input [INT_COUNT-1:0] requests;
        reg [$clog2(INT_COUNT)-1:0] result;
        reg found;
        begin
            found = 0;
            for (i = INT_COUNT-1; i >=0; i = i - 1) begin
                if (requests[i] && !found) begin
                    result = i;
                    found = 1;
                end
            end
            priority_encoder = result;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interrupt_pending <= 0;
            interrupt_mask <= 0;
            interrupt_service <= 0;
            current_interrupt <= 0;
            interrupt_active <= 0;
        end else begin
            interrupt_pending <= (interrupt_pending | interrupt_requests) & ~interrupt_mask;

            if (!interrupt_active && interrupt_pending) begin
                current_interrupt <= priority_encoder(interrupt_pending);
                interrupt_active <= 1;
                interrupt_service <= (1 << priority_encoder(interrupt_pending));
            end

            if (interrupt_ack && interrupt_active) begin
                interrupt_mask[current_interrupt] <= 1;
                interrupt_pending[current_interrupt] <= 0;
                interrupt_service <= 0;
                interrupt_active <= 0;
            end
        end
    end

endmodule


// 7. L1_P20 msb_one_extractor ===========================================================
module msb_one_extractor (
    input wire [7:0] data_in,
    output reg [7:0] data_out
);

    always @(*) begin
        casex (data_in)
            8'b1xxxxxxx: data_out = 8'b10000000;
            8'b01xxxxxx: data_out = 8'b01000000;
            8'b001xxxxx: data_out = 8'b00100000;
            8'b0001xxxx: data_out = 8'b00010000;
            8'b00001xxx: data_out = 8'b00001000;
            8'b000001xx: data_out = 8'b00000100;
            8'b0000001x: data_out = 8'b00000010;
            8'b00000001: data_out = 8'b00000001;
	    default : data_out = 8'b00000000;
        endcase
    end

endmodule


// 8. L1_P21 edge_detector ===========================================================
module rising_edge_detector (
    input wire clk,
    input wire signal,
    output reg edge_detected
);

reg signal_prev;

always @(posedge clk) begin
    signal_prev <= signal;
    edge_detected <= signal && ~(signal_prev);
end

endmodule


// 9. L1_P24 param_mem ===========================================================
module param_mem #(
    parameter N = 4,               // address bit count (size 2^N)
    parameter DATA_WIDTH = 8       // data bit width
)(
    input wire clk,
    input wire [N-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire write_enable,
    output reg [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] memory [0:(2**N)-1];
    
   

    always @(posedge clk) begin
        if (write_enable) begin
            memory[addr] <= data_in;
        end

	else data_out <= memory[addr];
	

    end
endmodule
