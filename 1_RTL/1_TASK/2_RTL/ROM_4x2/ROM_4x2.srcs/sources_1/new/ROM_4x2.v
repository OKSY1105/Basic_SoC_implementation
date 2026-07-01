`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/25 02:09:41
// Design Name: 
// Module Name: ROM_4x2
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


module ROM_4x2(
i_clk,
i_rst_n,
i_addres,
o_out
    );
input i_clk;
input i_rst_n;
input [1:0] i_addres;
output [1:0] o_out;

    reg [1:0] o_out;
    always @(posedge i_clk) begin
        if(!i_rst_n) begin
            o_out<=0;
           end
        else begin
        case(i_addres)
        2'b00 : begin o_out[0]<=1; o_out[1]<=0; end
        2'b01 : begin o_out[0]<=0; o_out[1]<=1; end
        2'b10 : begin o_out[0]<=0; o_out[1]<=0; end
        2'b11 : begin o_out[0]<=1; o_out[1]<=1; end
        endcase
       end
    end
s
endmodule
