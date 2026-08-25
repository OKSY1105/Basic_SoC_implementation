module cache(

i_clk,
i_rstn,
i_cpu_req, // cpu request
i_cache_write, // cpu is going to write data to cache
i_cpu_memaddr, // cpu give memory address to cache
i_cpu_wdata, // cpu is going to write wdata
o_cpu_ack, // cache tell cpu i finish work that you request
o_cpu_rdata, // cpu read data

o_mem_req, // miss cache reqest data to memory
o_mem_write, // cache data is going to written to memory
o_mem_address, //cache give  memory address 
o_mem_wdata, // cahce is going to write wdata to memory
i_mem_ack, // memory tell cache i finish work that you request
i_mem_rdata // data is written to cache

);
input i_cpu_req;
input i_cpu_write;
input [7:0] i_cpu_memaddr;
input [15:0] i_cpu_wdata;
output o_cpu_ack;
output [15:0] o_cpu_rdata;

reg [15:0] cache [7:0]; // I need to make it  SRAM module later.
reg [7:0] valid;

wire [1:0] w_tag;     // i_cpu_memaddr - index - offset 
wire [2:0] w_index;  // size of cache
wire [1:0] w_offset; //size of byte
reg [1:0] r_cache_tag;     // i_cpu_memaddr - index - offset
reg [2:0] r_cache_index;  // size of cache
reg [1:0] r_cache_offset; //size of byte


wire hit;
wire miss;

assign hit = i_cpu_req & valid &(r_cache_tag == w_tag); 


endmodule
