module cache(

i_cache_req,
i_cache_write,
i_cache_address,
i_cpu_wdata,
o_cpu_ack,
o_cpu_rdata,

o_mem_req,
o_mem_write,
o_mem_address,
o_mem_wdata,
i_mem_ack,
i_mem_rdata

);
input i_cache_req;
input i_cpu_write;
input [5:0] i_cache_address;
input [15:0] i_cpu_wdata;
output o_cpu_ack;
output [15:0] o_cpu_rdata;

reg [15:0] cache [7:0]; // I need to make it  SRAM module later.

reg [7:0] valid;

wire [1:0] w_tag; 
wire [2:0] w_index;
wire [15:0] data_rd;


wire w_cpu_read = i_cache_req & o_cpu_ack & ~(i_cache_write);

wire hit = (w_cpu_read & valid) &&( w_tag == i_cache_address [5:3]);

assign o_cpu_rdata = hit ? data_rd : 


endmodule
