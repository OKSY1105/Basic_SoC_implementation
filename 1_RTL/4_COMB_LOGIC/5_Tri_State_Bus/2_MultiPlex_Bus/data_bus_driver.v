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

wire  r_mux ;

assign r_mux = i_en1 ^ i_en2;

assign o_bus_data = r_mux ? (i_en1 ? i_in1 : i_in2) : 8'bzzzz_zzzz;  



endmodule








