module ifcase(

i_sel,
o_normal_if,
o_normal_case,
o_normal_ternary,
o_latch_if,
o_latch_case

);
input [1:0] i_sel;
output [1:0] o_normal_if; 
output [1:0] o_normal_case; 
output [1:0] o_normal_ternary; 
output [1:0] o_latch_if; 
output [1:0] o_latch_case; 

reg [1:0] o_normal_if;
reg [1:0] o_normal_case;

reg [1:0] o_latch_if;
reg [1:0] o_latch_case;

always @ (*) begin
 	if(i_sel == 2'b00) o_normal_if = 2'b01;
	else if(i_sel ==2'b01) o_normal_if = 2'b10;
	else if(i_sel == 2'b10) o_normal_if = 2'b11;
	else o_normal_if = 2'b00;


end

always @ (*) begin
        case(i_sel)
                2'b00 : o_normal_case = 2'b11;
                2'b01 : o_normal_case = 2'b00;
                2'b10 : o_normal_case = 2'b01;
                2'b11 : o_normal_case = 2'b10;
        endcase


end


assign o_normal_ternary = (i_sel == 2'b00) ? 2'b10 :
       			  (i_sel == 2'b01) ? 2'b11 :
       			  (i_sel == 2'b10) ? 2'b00 : 2'b01 ;




always @ (*) begin
        if(i_sel == 2'b10) o_latch_if = 2'b01;
        


end

always @ (*) begin
        case(i_sel)
                2'b00 : o_latch_case = 2'b11;
                2'b01 : o_latch_case = 2'b00;
                2'b10 : o_latch_case = 2'b01;
                
        endcase


end



endmodule
