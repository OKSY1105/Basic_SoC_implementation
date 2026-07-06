module bidir_bus(

i_data_to_bus,
i_send,
i_rcv,
io_bus_data,
o_data_from_bus

);

input [7:0] i_data_to_bus; 
input i_send;
input i_rcv;

inout [7:0] io_bus_data;
output [7:0] o_data_from_bus;


assign io_bus_data = (i_send) ? i_data_to_bus: 8'hZ;

reg [7:0] o_data_from_bus;

always @(*) begin
 if(i_rcv) o_data_from_bus =io_bus_data;
 else o_data_from_bus =8'hZ;


end


endmodule
