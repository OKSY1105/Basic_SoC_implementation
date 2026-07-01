`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/23 01:06:57
// Design Name: 
// Module Name: shift_reg
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


module shift_reg(
i_clk,
i_rst_n,
i_data1,
o_data
    );
input i_clk;
input i_rst_n;
input [3:0] i_data1;
output [3:0] o_data;
reg [3:0] r_ff1;
reg [3:0] r_ff2; 
reg [3:0] r_ff3;
reg [3:0] r_ff4;   

always @(posedge i_clk) begin
    if(!(i_rst_n)) begin
        r_ff1<=0;
        r_ff2<=0;
        r_ff3<=0;
        r_ff4<=0;
     end
     
     else begin
        r_ff1<= i_data1;
        r_ff2<=r_ff1;
        r_ff3<=r_ff2;
        r_ff4<=r_ff3;
     end 
        
          
        
    
end  
assign o_data = r_ff4;    
endmodule
