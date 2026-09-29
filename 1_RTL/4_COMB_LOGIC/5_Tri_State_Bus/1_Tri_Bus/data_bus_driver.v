module data_bus_driver(

i_in1,
i_in2,
i_en1,
i_en2,
o_bus_data

);


input [7:0] i_in1;
input [7:0] i_in2;
input i_en1;
input i_en2;

output [7:0] o_bus_data;
reg [7:0] o_bus_data;

always @(*) begin

	case({i_en1, i_en2})
	2'b10 : o_bus_data = i_in1;
	2'b01 : o_bus_data = i_in2;
	default : o_bus_data =8'hZ;



	endcase




end 




endmodule




