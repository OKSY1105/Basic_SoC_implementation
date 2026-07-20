module cache(

i_cahe_req,
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

reg [15:0] cache [7:0];

endmodule
