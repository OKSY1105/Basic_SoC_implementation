module shift_register(

i_clk,
i_rstn,
i_data,

o_data
);


input i_clk;
input i_rstn;
input  i_data;

output [7:0] o_data;

//reg [7:0] r_data;

reg [7:0] r_shift;

always @(posedge i_clk) begin
	
if(!i_rstn) begin
//r_data <=8'b0;
r_shift <=8'b0;
end
else begin
//r_data <= {r_data[6:0] ,i_data};
r_shift<={ r_shift[6:0], i_data};

//r_shift = r_shift <<1;
//r_shift [0] = i_data;

end

end

assign o_data = r_shift;

endmodule 

