`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/30 00:37:53
// Design Name: 
// Module Name: tb_RAM
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


module tb_RAM;

reg i_clk;
reg i_rstn;
reg i_bitline;
reg i_worldline;
reg i_WE;

wire o_outline;

initial begin
    i_clk=0;
    i_worldline =0;
i_bitline =0;
i_WE =0;
    forever #5 i_clk = ~i_clk;
end

initial begin

 
 #10 i_rstn = 1;
    i_WE = 1;

#10 i_worldline = 1;
    i_bitline = 1;    // write: r_hold <= 1

#10 i_worldline = 0; // hold

#10 i_WE = 0;        // read 모드로 전환
    i_worldline = 1; // ← WL=1이어야 read 실행됨!

#10 i_worldline = 0;

end

RAM_latch DUT(
.i_clk(i_clk),
.i_rstn(i_rstn), 
.i_bitline(i_bitline), 
.i_worldline(i_worldline),
.i_WE(i_WE), 
.o_outline(o_outline)
);





endmodule
