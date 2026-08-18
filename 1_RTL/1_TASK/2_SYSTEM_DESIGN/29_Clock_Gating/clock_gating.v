`timescale 1ns / 1ps

module clock_gating(

i_clk,
i_rst_n,
i_en,
i_data,
o_data_out

);

input i_clk, i_rst_n, i_en;
input [7:0] i_data;
output [7:0] o_data_out;

reg [7:0] o_data_out;
reg r_en;
wire w_gate_clk;

always @(posedge i_clk or i_en or  negedge i_rst_n) begin
	if(!i_rst_n) r_en<= 0;
		
	
	else begin
		if(i_clk) r_en <= i_en;
	end
end

assign w_gate_clk = i_clk & r_en;

always @(posedge i_clk or negedge i_rst_n) begin
       if(!i_rst_n) o_data_out <=0;
       else begin
	       if(w_gate_clk) o_data_out <=i_data;
	       else o_data_out <= o_data_out;
       end
end       
endmodule


