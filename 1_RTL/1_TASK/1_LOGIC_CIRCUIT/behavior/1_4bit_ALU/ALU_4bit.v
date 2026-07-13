module 4bit_ALU(

i_S,
i_A,
i_B,
i_M,
i_Cin,

o_Cout,
o_out
);

input i_M;
input [3:0] i_S;
input [3:0] i_A;
input [3:0] i_B;
input i_Cin;

output o_Cout;
output [3:0] o_out;

reg o_Cout
reg [3:0] o_output

always @(*) begin


	if(!(i_M)) begin
		
		if(!(i_Cin)) begin

			case(i_S)

				4'b0000 : {o_Cout,o_out} = i_A-1;
				4'b0001 : {o_Cout,o_out} = (i_A & i_B) -1; 
				4'b0010 : {o_Cout,o_out} = (i_A & ~i_B)-1;
				4'b0011 : {o_Cout,o_out} = -1;
			        4'b0100 : {o_Cout,o_out} = i_A + (i_A | ~i_B);	
			        4'b0101 : {o_Cout,o_out} = (i_A & i_B) + (i_A |~i_B);	
			        4'b0110 : {o_Cout,o_out} = i_A - i_B- 1;
			        4'b0111 : {o_Cout,o_out} = i_A | ~i_B;	
			        4'b1000 : {o_Cout,o_out} = i_A + (i_A | i_B);	
			        4'b1001 : {o_Cout,o_out} = i_A +i_B;
			        4'b1010 : {o_Cout,o_out} = (i_A & ~i_B) + (i_A | i_B);	
			        4'b1011 : {o_Cout,o_out} = (i_A | i_B);	
				4'b1100 : begin  o_out = {i_A[2:0], i_Cin};
						o_Cout = i_A[3];	
			       		end	
						
			        4'b1101 : {o_Cout,o_out} =(i_A & i_B) + i_A;	
			        4'b1110 : {o_Cout,o_out} =(i_A & ~i_B) +i_A; 	
			        4'b1111 : {o_Cout,o_out} = i_A;	

			endcase
		end
		
		else begin
				4'b0000 : {o_Cout,o_out} = i_A;
	                        4'b0001 : {o_Cout,o_out} = (i_A & i_B);
                                4'b0010 : {o_Cout,o_out} = (i_A & ~i_B);
                                4'b0011 : {o_Cout,o_out} = 5'd0;
                                4'b0100 : {o_Cout,o_out} = i_A + (i_A | ~i_B)+1;
                                4'b0101 : {o_Cout,o_out} = (i_A & i_B) + (i_A |~i_B)+1;
                                4'b0110 : {o_Cout,o_out} = i_A - i_B;
                                4'b0111 : {o_Cout,o_out} = (i_A | ~i_B) + 1;
                                4'b1000 : {o_Cout,o_out} = i_A + (i_A | i_B)+1;
                                4'b1001 : {o_Cout,o_out} = (i_A +i_B)-1;
                                4'b1010 : {o_Cout,o_out} = (i_A & ~i_B) + (i_A | i_B) +1;
                                4'b1011 : {o_Cout,o_out} = (i_A | i_B)+1;
                                4'b1100 : {o_Cout,o_out} = (i_A + i_A)+1;
                                4'b1101 : {o_Cout,o_out} =(i_A & i_B) + i_A + 1;
                                4'b1110 : {o_Cout,o_out} =(i_A & ~i_B) +i_A+1;
                                4'b1111 : {o_Cout,o_out} = i_A+1;

		end



	end

	
	else begin
				4'b0000 : o_out = ~(i_A);
                                4'b0001 : o_out = ~(i_A & i_B);
                                4'b0010 : o_out = ~(i_A & ~i_B);
                                4'b0011 : o_out = 4'd1;
                                4'b0100 : o_out = ~(i_A | i_B);
                                4'b0101 : o_out = ~(i_B);
                                4'b0110 : o_out = ~(i_A ^ i_B);
                                4'b0111 : o_out = ~(~i_A & i_B);
                                4'b1000 : o_out =  (~i_A & i_B);
                                4'b1001 : o_out = i_A ^i_B;
                                4'b1010 : o_out = (i_B) ;
                                4'b1011 : o_out = (i_A | i_B);
                                4'b1100 : o_out = 4'd0;
                                4'b1101 : o_out = (i_A & ~i_B) ;
                                4'b1110 : o_out = (i_A & i_B) ;
                                4'b1111 : o_out = i_A;


	end

end





end

endmodule
