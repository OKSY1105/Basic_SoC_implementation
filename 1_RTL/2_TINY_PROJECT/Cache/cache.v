`timescale 1ns/1ps
// Direct-mapped, write-back, write-allocate data cache for the 8bit SoC RAM
// path: RAM AHB slave wrapper -> cache -> DRAM controller (2 KiB local RAM).
//
// CPU side (byte): one request at a time. Hold req, address, write and wdata
//   until ack; req && ack at a rising edge completes the access exactly once.
//   A hit acknowledges in the same cycle the request is presented.
// Memory side (line): one 64-bit line request at a time with the same req/ack
//   rule. A line is one DRAM column burst (BL8 x 8bit); o_mem_address is the
//   line number = byte address [10:3] = {row[3:0], column[3:0]}. Byte k of a
//   line is bits [8k+7:8k], matching the DRAM controller's byte offset.
// Miss: write the victim line back if it is dirty, then refill the requested
//   line; the held request then hits and is acknowledged.
// Reset clears valid/dirty only. Dirty data not yet written back is lost.
// Counters: completed CPU accesses, misses (refills) and write-backs.
module cache #(
    parameter integer INDEX_W = 3                 // 2**INDEX_W lines of 8 bytes
) (
    input  wire        i_clk,
    input  wire        i_rstn,
    // CPU side
    input  wire        i_cpu_req,                 // request, held until ack
    input  wire        i_cpu_write,               // 1: write i_cpu_wdata
    input  wire [10:0] i_cpu_memaddr,             // RAM local byte address
    input  wire [7:0]  i_cpu_wdata,
    output wire        o_cpu_ack,                 // access completes this cycle
    output wire [7:0]  o_cpu_rdata,               // valid while o_cpu_ack
    // Memory side
    output reg         o_mem_req,                 // line request, held until ack
    output reg         o_mem_write,               // 1: write back o_mem_wdata
    output reg  [7:0]  o_mem_address,             // line number {row, column}
    output reg  [63:0] o_mem_wdata,
    input  wire        i_mem_ack,                 // line access completes
    input  wire [63:0] i_mem_rdata,               // refill data, valid with ack
    // Measurement
    output reg  [15:0] o_access_count,
    output reg  [15:0] o_miss_count,
    output reg  [15:0] o_writeback_count
);
    localparam integer LINES = 1 << INDEX_W;
    localparam integer TAG_W = 8 - INDEX_W;
    localparam [1:0] ST_IDLE = 2'd0, ST_WRITEBACK = 2'd1, ST_REFILL = 2'd2;

    // Line storage (no reset, so tools may map it to distributed RAM).
    reg [63:0] r_data [0:LINES-1];
    reg [TAG_W-1:0] r_tag [0:LINES-1];
    // Line state and miss handling.
    reg [LINES-1:0] r_valid, r_dirty;
    reg [1:0] r_state;
    reg [INDEX_W-1:0] r_miss_index;
    reg [TAG_W-1:0] r_miss_tag;

    wire [2:0] w_offset = i_cpu_memaddr[2:0];
    wire [INDEX_W-1:0] w_index = i_cpu_memaddr[INDEX_W+2:3];
    wire [TAG_W-1:0] w_tag = i_cpu_memaddr[10:INDEX_W+3];
    wire [63:0] w_line = r_data[w_index];
    wire w_hit = r_valid[w_index] && (r_tag[w_index] == w_tag);
    wire w_idle_req = i_cpu_req && (r_state == ST_IDLE);
    wire w_victim_dirty = r_valid[w_index] && r_dirty[w_index];
    // Write hit: replace one byte of the line.
    wire [63:0] w_byte_mask = 64'hff << {w_offset, 3'b000};
    wire [63:0] w_merged = (w_line & ~w_byte_mask) |
                           ({56'd0, i_cpu_wdata} << {w_offset, 3'b000});

    assign o_cpu_ack = w_idle_req && w_hit;
    assign o_cpu_rdata = w_line[{w_offset, 3'b000} +: 8];

    always @(posedge i_clk) begin
        if (o_cpu_ack && i_cpu_write) r_data[w_index] <= w_merged;
        if (r_state == ST_REFILL && i_mem_ack) begin
            r_data[r_miss_index] <= i_mem_rdata;
            r_tag[r_miss_index] <= r_miss_tag;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_valid <= {LINES{1'b0}}; r_dirty <= {LINES{1'b0}};
            r_state <= ST_IDLE;
            r_miss_index <= {INDEX_W{1'b0}}; r_miss_tag <= {TAG_W{1'b0}};
            o_mem_req <= 1'b0; o_mem_write <= 1'b0;
            o_mem_address <= 8'd0; o_mem_wdata <= 64'd0;
            o_access_count <= 16'd0; o_miss_count <= 16'd0;
            o_writeback_count <= 16'd0;
        end else begin
            case (r_state)
                ST_IDLE: begin
                    if (o_cpu_ack) begin
                        o_access_count <= o_access_count + 16'd1;
                        if (i_cpu_write) r_dirty[w_index] <= 1'b1;
                    end else if (w_idle_req) begin
                        // Miss: keep the request's line; evict the victim.
                        o_miss_count <= o_miss_count + 16'd1;
                        r_miss_index <= w_index; r_miss_tag <= w_tag;
                        o_mem_req <= 1'b1;
                        if (w_victim_dirty) begin
                            r_state <= ST_WRITEBACK; o_mem_write <= 1'b1;
                            o_mem_address <= {r_tag[w_index], w_index};
                            o_mem_wdata <= w_line;
                        end else begin
                            r_state <= ST_REFILL; o_mem_write <= 1'b0;
                            o_mem_address <= {w_tag, w_index};
                        end
                    end
                end
                ST_WRITEBACK: if (i_mem_ack) begin
                    o_writeback_count <= o_writeback_count + 16'd1;
                    r_dirty[r_miss_index] <= 1'b0;
                    r_state <= ST_REFILL; o_mem_write <= 1'b0;
                    o_mem_address <= {r_miss_tag, r_miss_index};
                end
                ST_REFILL: if (i_mem_ack) begin
                    r_valid[r_miss_index] <= 1'b1;
                    r_dirty[r_miss_index] <= 1'b0;
                    r_state <= ST_IDLE; o_mem_req <= 1'b0;
                end
                default: r_state <= ST_IDLE;
            endcase
        end
    end
endmodule
