`timescale 1ns/1ps
// Direct-mapped, write-back, write-allocate data cache with an AMBA AHB-Lite
// slave port, for the 8bit SoC RAM region (0x8000-0x87FF):
//   CPU data port -> AHB decoder (HSEL) -> cache -> DRAM controller -> DRAM.
//
// AHB-Lite slave, 8-bit data:
//   - An address phase is accepted when HSEL && HTRANS[1] && HREADY.
//     HADDR[10:0] is the RAM local byte address; the decoder has already
//     checked HADDR[15:11]. IDLE/BUSY get zero-wait OKAY.
//   - Byte transfers only. HSIZE other than 000 gets a two-cycle ERROR with
//     no side effect.
//   - A hit completes in its first data-phase cycle (zero wait), so
//     back-to-back hits run one per clock. A miss holds HREADYOUT low through
//     the optional dirty write-back and the refill, then completes as a hit.
//   - HREADYOUT/HRESP depend only on the registered data-phase state.
// Memory side (line): one 64-bit line request at a time. Hold req, address,
//   write and wdata until ack; req && ack at a rising edge completes it once.
//   A line is one DRAM column burst (BL8 x 8bit); o_mem_address is the line
//   number = byte address [10:3] = {row, column}; byte k is bits [8k+7:8k].
// Reset clears valid/dirty only. Dirty data not yet written back is lost.
// Counters: completed byte accesses, misses (refills) and write-backs.
module cache #(
    parameter integer INDEX_W = 3                 // 2**INDEX_W lines of 8 bytes
) (
    input  wire        i_clk,
    input  wire        i_rstn,
    // AHB-Lite slave
    input  wire        i_hsel,
    input  wire [15:0] i_haddr,
    input  wire [1:0]  i_htrans,
    input  wire        i_hwrite,
    input  wire [2:0]  i_hsize,
    input  wire [7:0]  i_hwdata,
    input  wire        i_hready,                  // bus HREADY (all slaves)
    output wire        o_hreadyout,
    output wire        o_hresp,                   // 1 = ERROR
    output wire [7:0]  o_hrdata,
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
    reg [LINES-1:0] r_valid, r_dirty;
    reg [1:0] r_state;
    // Data phase of the accepted transfer.
    reg r_dp, r_dp_write;
    reg [10:0] r_dp_addr;
    reg r_err, r_err2;                            // ERROR first / second cycle

    wire w_accept = i_hsel && i_htrans[1] && i_hready;
    wire [2:0] w_offset = r_dp_addr[2:0];
    wire [INDEX_W-1:0] w_index = r_dp_addr[INDEX_W+2:3];
    wire [TAG_W-1:0] w_tag = r_dp_addr[10:INDEX_W+3];
    wire [63:0] w_line = r_data[w_index];
    wire w_hit = r_valid[w_index] && (r_tag[w_index] == w_tag);
    wire w_done = r_dp && (r_state == ST_IDLE) && w_hit;
    wire w_victim_dirty = r_valid[w_index] && r_dirty[w_index];
    // Write hit: replace one byte of the line with HWDATA (data phase).
    wire [63:0] w_byte_mask = 64'hff << {w_offset, 3'b000};
    wire [63:0] w_merged = (w_line & ~w_byte_mask) |
                           ({56'd0, i_hwdata} << {w_offset, 3'b000});

    assign o_hreadyout = r_err ? r_err2 : (!r_dp || w_done);
    assign o_hresp = r_err;
    assign o_hrdata = w_line[{w_offset, 3'b000} +: 8];

    always @(posedge i_clk) begin
        if (w_done && r_dp_write) r_data[w_index] <= w_merged;
        if (r_state == ST_REFILL && i_mem_ack) begin
            r_data[w_index] <= i_mem_rdata;
            r_tag[w_index] <= w_tag;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_valid <= {LINES{1'b0}}; r_dirty <= {LINES{1'b0}};
            r_state <= ST_IDLE;
            r_dp <= 1'b0; r_dp_write <= 1'b0; r_dp_addr <= 11'd0;
            r_err <= 1'b0; r_err2 <= 1'b0;
            o_mem_req <= 1'b0; o_mem_write <= 1'b0;
            o_mem_address <= 8'd0; o_mem_wdata <= 64'd0;
            o_access_count <= 16'd0; o_miss_count <= 16'd0;
            o_writeback_count <= 16'd0;
        end else begin
            // AHB: when HREADY is high the current data phase (ours or another
            // slave's) ends and the address phase on the bus may start a new one.
            if (i_hready) begin
                r_dp <= w_accept && (i_hsize == 3'b000);
                r_err <= w_accept && (i_hsize != 3'b000);
                r_err2 <= 1'b0;
                if (w_accept) begin
                    r_dp_addr <= i_haddr[10:0]; r_dp_write <= i_hwrite;
                end
            end else if (r_err) begin
                r_err2 <= 1'b1;
            end

            case (r_state)
                ST_IDLE: begin
                    if (w_done) begin
                        o_access_count <= o_access_count + 16'd1;
                        if (r_dp_write) r_dirty[w_index] <= 1'b1;
                    end else if (r_dp) begin
                        // Miss: write the victim back if dirty, then refill.
                        o_miss_count <= o_miss_count + 16'd1;
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
                    r_dirty[w_index] <= 1'b0;
                    r_state <= ST_REFILL; o_mem_write <= 1'b0;
                    o_mem_address <= {w_tag, w_index};
                end
                ST_REFILL: if (i_mem_ack) begin
                    r_valid[w_index] <= 1'b1;
                    r_dirty[w_index] <= 1'b0;
                    r_state <= ST_IDLE; o_mem_req <= 1'b0;
                end
                default: r_state <= ST_IDLE;
            endcase
        end
    end
endmodule
