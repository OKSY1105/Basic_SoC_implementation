`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/27 02:06:53
// Design Name: 
// Module Name: RAM
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


module RAM(
i_rst_n,
i_address,
i_WE,
i_data,
o_outdata
    );
    input i_rst_n;
    input i_address;
    input i_WE;
    input  i_data;
    output o_outdata;
    
endmodule



module RAM_latch(
i_clk,
i_rstn,
i_bitline,
i_worldline,
i_WE,
o_outline
);
input i_clk;
input i_rstn;
input i_bitline;
input i_WE;
input i_worldline;
output o_outline;

reg r_hold;
reg o_outline;

always @(posedge i_clk) begin
    if(!i_rstn) begin
        r_hold <=0;
        o_outline<=0;
    end
    
    else if(i_worldline) begin
        if (i_WE) r_hold <= i_bitline;
        else  o_outline <= r_hold;
     end
    
end

endmodule






