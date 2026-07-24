`timescale 1ns / 1ps

module mux_demux(
    // 2 to 1
    i_mux_2_to_1_0,
    i_mux_2_to_1_1,
    i_mux_2_to_1_sel,
    o_mux_2_to_1,

    // 9 to 1
    i_mux_9_to_1_0,
    i_mux_9_to_1_1,
    i_mux_9_to_1_2,
    i_mux_9_to_1_3,
    i_mux_9_to_1_4,
    i_mux_9_to_1_5,
    i_mux_9_to_1_6,
    i_mux_9_to_1_7,
    i_mux_9_to_1_8,
    i_mux_9_to_1_sel,
    o_mux_9_to_1,

    // 256 to 1
    i_mux_256_to_1,
    i_mux_256_to_1_sel,
    o_mux_256_to_1,

    // 1 to 2
    i_demux_1_to_2,
    i_demux_1_to_2_sel,
    o_demux_1_to_2_0,
    o_demux_1_to_2_1,

    // 1 to 9
    i_demux_1_to_9,
    i_demux_1_to_9_sel,
    o_demux_1_to_9_0,
    o_demux_1_to_9_1,
    o_demux_1_to_9_2,
    o_demux_1_to_9_3,
    o_demux_1_to_9_4,
    o_demux_1_to_9_5,
    o_demux_1_to_9_6,
    o_demux_1_to_9_7,
    o_demux_1_to_9_8,

    // 1 to 256
    i_demux_1_to_256,
    i_demux_1_to_256_sel,
    o_demux_1_to_256
);

    // ==========================================
    // Input Definitions
    // ==========================================
    // 2 to 1
    input  [3:0]    i_mux_2_to_1_0;
    input  [3:0]    i_mux_2_to_1_1;
    input           i_mux_2_to_1_sel;

    // 9 to 1
    input  [3:0]    i_mux_9_to_1_0;
    input  [3:0]    i_mux_9_to_1_1;
    input  [3:0]    i_mux_9_to_1_2;
    input  [3:0]    i_mux_9_to_1_3;
    input  [3:0]    i_mux_9_to_1_4;
    input  [3:0]    i_mux_9_to_1_5;
    input  [3:0]    i_mux_9_to_1_6;
    input  [3:0]    i_mux_9_to_1_7;
    input  [3:0]    i_mux_9_to_1_8;
    input  [3:0]    i_mux_9_to_1_sel;

    // 256 to 1
    input  [2047:0] i_mux_256_to_1;
    input  [7:0]    i_mux_256_to_1_sel;

    // 1 to 2
    input  [3:0]    i_demux_1_to_2;
    input           i_demux_1_to_2_sel;

    // 1 to 9
    input  [3:0]    i_demux_1_to_9;
    input  [3:0]    i_demux_1_to_9_sel;

    // 1 to 256
    input  [7:0]    i_demux_1_to_256;
    input  [7:0]    i_demux_1_to_256_sel;

    // ==========================================
    // Output Definitions
    // ==========================================
    // 2 to 1
    output [3:0]    o_mux_2_to_1;

    // 9 to 1
    output [3:0]    o_mux_9_to_1;

    // 256 to 1
    output [7:0]    o_mux_256_to_1;

    // 1 to 2
    output [3:0]    o_demux_1_to_2_0;
    output [3:0]    o_demux_1_to_2_1;

    // 1 to 9
    output [3:0]    o_demux_1_to_9_0;
    output [3:0]    o_demux_1_to_9_1;
    output [3:0]    o_demux_1_to_9_2;
    output [3:0]    o_demux_1_to_9_3;
    output [3:0]    o_demux_1_to_9_4;
    output [3:0]    o_demux_1_to_9_5;
    output [3:0]    o_demux_1_to_9_6;
    output [3:0]    o_demux_1_to_9_7;
    output [3:0]    o_demux_1_to_9_8;

    // 1 to 256
    output [2047:0] o_demux_1_to_256;

    // ==========================================
    // Reg Definitions
    // ==========================================
    // 9 to 1
    reg    [3:0]    o_mux_9_to_1;
    
    // 256 to 1
    reg    [7:0]    o_mux_256_to_1;

    // 1 to 9
    reg    [3:0]    o_demux_1_to_9_0;
    reg    [3:0]    o_demux_1_to_9_1;
    reg    [3:0]    o_demux_1_to_9_2;
    reg    [3:0]    o_demux_1_to_9_3;
    reg    [3:0]    o_demux_1_to_9_4;
    reg    [3:0]    o_demux_1_to_9_5;
    reg    [3:0]    o_demux_1_to_9_6;
    reg    [3:0]    o_demux_1_to_9_7;
    reg    [3:0]    o_demux_1_to_9_8;

    // 1 to 256
    reg    [2047:0] o_demux_1_to_256;

    reg [8:0] i;


// (1)2 to 1
assign o_mux_2_to_1 =  i_mux_2_to_1_sel ? i_mux_2_to_1_1 : i_mux_2_to_1_0;

// (2) 9 to 1
always @(*) begin
	case(i_mux_9_to_1_sel)
		4'b0000: o_mux_9_to_1=i_mux_9_to_1_0;
		4'b0001: o_mux_9_to_1=i_mux_9_to_1_1;
		4'b0010: o_mux_9_to_1=i_mux_9_to_1_2;
		4'b0011: o_mux_9_to_1=i_mux_9_to_1_3;
		4'b0100: o_mux_9_to_1=i_mux_9_to_1_4;
		4'b0101: o_mux_9_to_1=i_mux_9_to_1_5;
		4'b0110: o_mux_9_to_1=i_mux_9_to_1_6;
		4'b0111: o_mux_9_to_1=i_mux_9_to_1_7;
		4'b1000: o_mux_9_to_1=i_mux_9_to_1_8;
		default :o_mux_9_to_1= 4'b0000;
	endcase
end


//(3) 256 to 1 

always @(*) begin
	o_mux_256_to_1 = 8'd0;
	for(i=0; i<256; i=i+1)begin
		if(i_mux_256_to_1_sel == i) begin
			o_mux_256_to_1 = i_mux_256_to_1[i*8 + :8];
		end
		
	end
end




// (4) 1 to 2
assign o_demux_1_to_2_0 = i_demux_1_to_2_sel ? 4'b0000 :i_demux_1_to_2 ;
assign o_demux_1_to_2_1 = i_demux_1_to_2_sel ? i_demux_1_to_2 : 4'b0000;


always @(*) begin
	o_demux_1_to_9_0 = 8'd0 ;
        o_demux_1_to_9_1 = 8'd0 ;
        o_demux_1_to_9_2 = 8'd0 ;
        o_demux_1_to_9_3 = 8'd0 ;
        o_demux_1_to_9_4 = 8'd0 ;
        o_demux_1_to_9_5 = 8'd0 ;
        o_demux_1_to_9_6 = 8'd0 ;
        o_demux_1_to_9_7 = 8'd0 ;
        o_demux_1_to_9_8 = 8'd0 ;

        case(i_demux_1_to_9_sel)
                4'b0000: o_demux_1_to_9_0 = i_demux_1_to_9 ;
                4'b0001: o_demux_1_to_9_1 = i_demux_1_to_9 ;
                4'b0010: o_demux_1_to_9_2 = i_demux_1_to_9 ;
                4'b0011: o_demux_1_to_9_3 = i_demux_1_to_9 ;
                4'b0100: o_demux_1_to_9_4 = i_demux_1_to_9 ;
                4'b0101: o_demux_1_to_9_5 = i_demux_1_to_9 ;
                4'b0110: o_demux_1_to_9_6 = i_demux_1_to_9 ;
                4'b0111: o_demux_1_to_9_7 = i_demux_1_to_9 ;
                4'b1000: o_demux_1_to_9_8 = i_demux_1_to_9 ;
		default : begin
			o_demux_1_to_9_0 = 8'd0 ;
       			o_demux_1_to_9_1 = 8'd0 ;
	       		o_demux_1_to_9_2 = 8'd0 ;
       			o_demux_1_to_9_3 = 8'd0 ;
      			o_demux_1_to_9_4 = 8'd0 ;
      			o_demux_1_to_9_5 = 8'd0 ;
       			o_demux_1_to_9_6 = 8'd0 ;
        	  	o_demux_1_to_9_7 = 8'd0 ;
       			o_demux_1_to_9_8 = 8'd0 ;

		end
        endcase
end

// (5) 1 to 256
always @(*) begin
	o_demux_1_to_256 =2048'd0;
	for(i=0; i<256; i= i+1) begin
		if(i_demux_1_to_256_sel ==i) begin
			o_demux_1_to_256[i*8+ : 8] = i_demux_1_to_256;
		end
		else  o_demux_1_to_256[i*8+ : 8] = 8'd0; 
	end
end




endmodule

