`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/23 23:01:55
// Design Name: 
// Module Name: tb_shift_reg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_shift_reg;
reg i_rst_n;
reg i_clk ;
reg [3:0] i_data1;
wire o_out;


initial begin
i_clk =0;
 forever #5 i_clk =~i_clk;
end
initial begin
i_rst_n =0;
i_data1 = 4'b0000;

#10 i_rst_n =1;
#10 i_data1 = 4'b0001;
#10 i_data1 = 4'b0010;
#10 i_data1 = 4'b0100;
#10 i_data1 = 4'b1000;
#10 i_data1 = 4'b1001;
#10 i_data1 = 4'b1010;
#10 i_data1 = 4'b1011;

end

shift_reg DUT( 
.i_clk(i_clk),
.i_rst_n(i_rst_n), 
.i_data1(i_data1), 
.o_data(o_data)
);

endmodule
