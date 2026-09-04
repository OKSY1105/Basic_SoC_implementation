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
input [31:0] i_cpu_wdata;
output o_cpu_ack;
output [31:0] o_cpu_rdata;

output o_mem_req; // cache has no data that cpu wants so request data
output o_mem_write; // cache data is different from memory data so cache data will be written to memory
output [7:0] o_mem_address; // cache give address to memory
output [31:0] o_mem_wdata; // data is different from memory data so update data 
input i_mem_ack;   // memory give cache a signle it it done
input [31:0] i_mem_rdata; // cache write data from memory

reg [31:0] cache [7:0]; // I need to make it  SRAM module later.
reg [7:0] valid_mem;

wire [2:0] w_tag =i_cpu_memaddr[7:5];     // i_cpu_memaddr - index - offset 
wire [2:0] w_index =i_cpu_memaddr[4:2];  // size of cache
wire [1:0] w_offset = i_cpu_memaddr[1:0]; //size of byte

reg [2:0] cache_tag_mem[7:0];     // i_cpu_memaddr - index - offset
reg [2:0] cache_index_mem;  // size of cache
reg [1:0] cache_offset_mem; //size of byte
reg valid_rd;

wire empty;
wire hit;
wire miss;
wire diff;
wire hit_read;

assign empty = i_cpu_req & ~valid_mem[w_index];
assign hit = i_cpu_req & valid_mem[w_index] &(cache_tag_mem[w_index] == w_tag);
assign diff = i_cpu_req & valid_mem[w_index] &(cache_tag_mem[w_index] != w_tag);
assign miss = empty | diff;

assign hit_read = hit  & ~(i_cpu_write); 
assign hit_write = hit  & i_cpu_write;

reg [7:0] r_dirty;
always @(posedge i_clk or negedge i_rstn) begin 
	if(!i_rstn) begin 
		valid_mem <=8'b0;
		o_cpu_rdata <= 32'd0;
                o_cpu_ack <= 1'b0;
		r_dirty <=1'b0;

	end

	else begin
		o_cpu_ack <=0;

		if(i_mem_ack) begin    // cache is empty so get data from memry
			cache_tag_mem[w_index] <= w_tag;
			cache[w_index] <= i_mem_rdata;
			valid_mem[w_index] <= 1'b1;
		end

		else if(hit_read)begin // hit read
                        o_cpu_rdata <= cache[w_index];
                        o_cpu_ack <=1'b1;
                end
                
		else if(hit_write) begin // hit write
                        cache[w_index] <= i_cpu_wdata;
                        r_dirty[w_index] <= 1'b1;
                        o_cpu_ack <=1'b1;
                end

	end

end

endmodule
