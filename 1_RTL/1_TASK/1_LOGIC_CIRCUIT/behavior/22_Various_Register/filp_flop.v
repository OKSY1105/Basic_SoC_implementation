`timescale 1ns / 1ps

module register
(
    // ==========================================
    // Port Declarations
    // ==========================================
    i_clk,
    i_reset,
    i_areset,
    i_sel,
    i_in,
    o_out_0,
    o_out_1,
    o_out_2,
    o_out_3,
    o_out_4,
    o_out_5,
    o_out_6
);

    // ==========================================
    // Input/Output Definitions
    // ==========================================
    input             i_clk;
    input             i_reset;   // Synchronous Reset
    input             i_areset;  // Asynchronous Reset
    input  [1:0]      i_sel;
    input  [7:0]      i_in;

    output reg [7:0]  o_out_0;   // 1. Positive Clock Flop
    output reg [7:0]  o_out_1;   // 2. Negative Clock Flop
    output reg [7:0]  o_out_2;   // 3. Dual Edge Flop / Latch
    output reg [7:0]  o_out_3;   // 4. Posedge Clk Sync Reset
    output reg [7:0]  o_out_4;   // 5. Posedge Clk Async Reset
    output reg [15:0] o_out_5;   // 6. Byte Enable (16-bit register)
    output reg [7:0]  o_out_6;   // 7. Loopback Register

    // ==========================================
    // Logic Implementation
    // ==========================================

    // 1. Positive clock flop
    always @(posedge i_clk) begin
	    o_out_0 <= i_in;
    end

    // 2. Negative clock flop
    always @(negedge i_clk) begin
	    o_out_1<= i_in;
    end

    // 3. Both clock flop
    always @ (posedge i_clk or negedge i_clk) begin
	    o_out_2 <= i_in;
    end

    // 4. Pos clk sync reset
    always @(posedge i_clk) begin
	    if(i_reset) o_out_3 <=  0;
	    else o_out_3 <= i_in;
    end

    // 5. Pos clk pos async reset
    always @(posedge i_clk or posedge i_areset) begin
	    if(i_areset) o_out_4 <=0;
	    else o_out_4 <= i_in;
    end



    // 6. Byte enable
    
    always @(posedge i_clk or posedge i_areset) begin
	    if(i_areset) o_out_5<=15'd0;
	    
	    else begin
		    case(i_sel) 
			    2'b01 : o_out_5[7:0]<= i_in;
			    2'b10 : o_out_5[15:8] <= i_in;
			    2'b11 :begin
				    o_out_5[7:0]<= i_in;
				    o_out_5[15:8] <= i_in;
			    end
			    default : o_out_5 <=o_out_5;
		    endcase
	    end
	    
    end


    // 7. Loopback
    always @(posedge i_clk or posedge i_areset) begin
           
	    if(i_areset) o_out_6 <=0;
            else o_out_6 <= ~(o_out_6|i_in);
    end


endmodule
