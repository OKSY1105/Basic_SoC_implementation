module simple_register #(parameter WIDTH= 32) 
(

	i_clk,
	i_rstn,
	i_wen,
	i_wdata,
	o_rdata



);

input i_clk;
input i_rstn;
input i_wen;
input [WIDTH -1 :0] i_wdata;
output [WIDTH-1 :0] o_rdata;

reg [WIDTH-1 : 0 ] r_data;

always @(posedge i_clk) begin

	if(!i_rstn)begin
		r_data <= 32'h0000;
	end

	else begin
		if(i_wen) r_data <= i_wdata;
		else r_data <= o_rdata;

	end

end

assign o_rdata = r_data;

endmodule
