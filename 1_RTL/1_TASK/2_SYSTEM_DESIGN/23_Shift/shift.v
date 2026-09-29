`timescale 1ns / 1ps

module shift
(
    // ==========================================
    // Port Declarations
    // ==========================================
    i_clk,
    i_areset,
    i_bit_data,
    i_byte_data,
    i_load,
    i_en,
    o_out_bit_r_logical_shift,
    o_out_bit_l_logical_shift,
    o_out_byte_r_logical_shift,
    o_out_byte_l_logical_shift,
    o_out_bit_r_arithmetic_shift,
    o_out_byte_r_arithmetic_shift,
    o_out_bit_r_rotate,
    o_out_bit_l_rotate,
    o_out_byte_r_rotate,
    o_out_byte_l_rotate
);

    
    input                    i_clk;
    input                    i_areset;
    input  [3:0]             i_bit_data;
    input  [31:0]            i_byte_data;
    input                    i_load;
    input                    i_en;

    output reg [3:0]         o_out_bit_r_logical_shift;
    output reg [3:0]         o_out_bit_l_logical_shift;
    output reg [31:0]        o_out_byte_r_logical_shift;
    output reg [31:0]        o_out_byte_l_logical_shift;
    output reg signed [3:0]  o_out_bit_r_arithmetic_shift;
    output reg signed [31:0] o_out_byte_r_arithmetic_shift;
    output reg [3:0]         o_out_bit_r_rotate;
    output reg [3:0]         o_out_bit_l_rotate;
    output reg [31:0]        o_out_byte_r_rotate;
    output reg [31:0]        o_out_byte_l_rotate;

    always @ (posedge i_clk or posedge i_areset)begin
	    if(i_areset) begin
		        o_out_bit_r_logical_shift <=4'd0;
			o_out_bit_l_logical_shift <=4'd0;
   			o_out_byte_r_logical_shift <=32'd0;
   			o_out_byte_l_logical_shift <=32'd0;
  			o_out_bit_r_arithmetic_shift <=4'd0;
   			o_out_byte_r_arithmetic_shift <=32'd0;
   			o_out_bit_r_rotate <=4'd0;
    			o_out_bit_l_rotate <=4'd0;
    			o_out_byte_r_rotate <=32'd0;
   		 	o_out_byte_l_rotate <=32'd0;
	    end

	    else begin
		    if(i_load) begin
			o_out_bit_r_logical_shift <=i_bit_data;
                        o_out_bit_l_logical_shift <=i_bit_data;
                        o_out_byte_r_logical_shift <=i_byte_data;
                        o_out_byte_l_logical_shift <=i_byte_data;
                        o_out_bit_r_arithmetic_shift <=i_bit_data;
                        o_out_byte_r_arithmetic_shift <=i_byte_data;
                        o_out_bit_r_rotate <=i_bit_data;
                        o_out_bit_l_rotate <=i_bit_data;
                        o_out_byte_r_rotate <=i_byte_data;
                        o_out_byte_l_rotate <=i_byte_data;
				
		    end

		    else if((i_load==0) &&(i_en ==1))begin
			o_out_bit_r_logical_shift <=(o_out_bit_r_logical_shift>>1);
                        o_out_bit_l_logical_shift <=(o_out_bit_l_logical_shift<<1);
                        o_out_byte_r_logical_shift <=(o_out_byte_r_logical_shift>>8);
                        o_out_byte_l_logical_shift <=(o_out_byte_l_logical_shift<<8);
                        o_out_bit_r_arithmetic_shift <=(o_out_bit_r_arithmetic_shift>>>1);
                        o_out_byte_r_arithmetic_shift <=(o_out_byte_r_arithmetic_shift>>>8);
                        o_out_bit_r_rotate <={o_out_bit_r_rotate[0],o_out_bit_r_rotate[3:1]};
                        o_out_bit_l_rotate <={o_out_bit_l_rotate [2:0],o_out_bit_l_rotate[3]};
                        o_out_byte_r_rotate <={o_out_byte_r_rotate[7:0],o_out_byte_r_rotate[31:8]};
                        o_out_byte_l_rotate <={o_out_byte_l_rotate[23:0],o_out_byte_l_rotate[31:24]};	    
		    
		    
		    end
 
	    
	    
	    end




    end

endmodule
