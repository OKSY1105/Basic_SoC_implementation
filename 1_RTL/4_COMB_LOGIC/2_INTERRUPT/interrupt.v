module interrupt(

i_int_ack,
i_int_address,

o_int_req,
o_int_id

);

input i_int_ack;
input [7:0] i_int_address;

output o_int_req;
output [2:0] o_int_id;

reg [7:0] r_saveAD;
reg [2:0] o_int_id;
reg o_int_req;


always @(*) begin
	o_int_req    = 1'b0         ;          
    	o_int_id     = 3'b000       ;         
    	r_saveAD = i_int_address    ;       
	if(i_int_ack) r_saveAD = 8'b0000_0000;
	else begin

		casex(r_saveAD)
			8'b1xxx_xxxx : begin  o_int_id =3'b111; o_int_req=1; end  	
			8'b01xx_xxxx : begin  o_int_id =3'b110; o_int_req=1; end  	
			8'b001x_xxxx : begin  o_int_id =3'b101; o_int_req=1; end  	
			8'b0001_xxxx : begin  o_int_id =3'b100; o_int_req=1; end  	
			8'b0000_1xxx : begin  o_int_id =3'b011; o_int_req=1; end  	
			8'b0000_01xx : begin  o_int_id =3'b010; o_int_req=1; end  	
			8'b0000_001x : begin  o_int_id =3'b001; o_int_req=1; end  	
			8'b0000_0001 : begin  o_int_id =3'b000; o_int_req=1; end
			default : begin o_int_id =3'b000; o_int_req=0; end   	

		endcase

	end
end 



endmodule
