`timescale 1ns/1ps
// AHB-Lite master bus functional model for unit TBs (single transfers only).
//   - The TB queues transfers with push(). The BFM runs them pipelined: the
//     next address phase overlaps the current data phase.
//   - While HREADY is low the address phase and HWDATA are held.
//   - Each completed transfer appends one entry to results[] (in order).
//   - idle_before inserts IDLE cycles before a transfer. IDLE address phases
//     carry a random HADDR/HWRITE so slaves and decoders see junk addresses.
//   - cancel_on_error=1: in the second ERROR cycle the pending address phase
//     is replaced by IDLE and the transfer is re-issued later (AHB allows it).
//   - Reset drops the queue and the transfers in flight.
// Outputs change only at the rising clock edge.
module ahb_lite_master_bfm #(
    parameter integer ADDR_W = 16,
    parameter integer DATA_W = 8
) (
    input  wire              clk,
    input  wire              rstn,
    output reg  [ADDR_W-1:0] haddr,
    output reg  [1:0]        htrans,
    output reg               hwrite,
    output reg  [2:0]        hsize,
    output reg  [DATA_W-1:0] hwdata,
    input  wire [DATA_W-1:0] hrdata,
    input  wire              hready,
    input  wire              hresp
);
    typedef struct {
        int unsigned       id;
        logic [ADDR_W-1:0] addr;
        bit                write;
        bit [2:0]          size;
        logic [DATA_W-1:0] wdata;
        int unsigned       idle_before;
    } op_t;
    typedef struct {
        int unsigned       id;
        logic [ADDR_W-1:0] addr;
        bit                write;
        bit [2:0]          size;
        logic [DATA_W-1:0] wdata;
        logic [DATA_W-1:0] rdata;
        bit                resp;          // 1 = ERROR
        int unsigned       wait_cycles;   // data-phase cycles with HREADY low
    } res_t;

    op_t  q[$];
    res_t results[$];
    bit cancel_on_error = 1'b0;           // set by the TB
    int unsigned n_cancel = 0;
    int unsigned next_id = 0;

    bit ap_valid = 1'b0, dp_valid = 1'b0;
    op_t ap, dp;
    int unsigned dp_wait = 0, idle_left = 0;

    function automatic int unsigned push(input logic [ADDR_W-1:0] addr,
                                         input bit write,
                                         input logic [DATA_W-1:0] wdata,
                                         input int unsigned idle_before = 0,
                                         input bit [2:0] size = 3'b000);
        op_t o;
        o.id = next_id; o.addr = addr; o.write = write; o.wdata = wdata;
        o.size = size; o.idle_before = idle_before;
        next_id++;
        q.push_back(o);
        return o.id;
    endfunction

    function automatic bit idle();
        return !ap_valid && !dp_valid && idle_left == 0 && q.size() == 0;
    endfunction

    initial begin
        haddr = '0; htrans = 2'b00; hwrite = 1'b0; hsize = 3'b000; hwdata = '0;
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            q.delete();
            ap_valid = 1'b0; dp_valid = 1'b0; idle_left = 0; dp_wait = 0;
            htrans <= 2'b00;
        end else if (hready) begin
            // The data phase in progress completes at this edge.
            if (dp_valid) begin
                res_t r;
                r.id = dp.id; r.addr = dp.addr; r.write = dp.write; r.size = dp.size;
                r.wdata = dp.wdata; r.rdata = hrdata; r.resp = hresp;
                r.wait_cycles = dp_wait;
                results.push_back(r);
            end
            // The address phase on the bus becomes the data phase.
            dp_valid = ap_valid; dp = ap; dp_wait = 0;
            if (ap_valid) hwdata <= ap.wdata;
            // Next address phase.
            if (idle_left != 0) begin
                idle_left--; ap_valid = 1'b0;
            end else if (q.size() != 0 && q[0].idle_before != 0) begin
                idle_left = q[0].idle_before - 1; q[0].idle_before = 0;
                ap_valid = 1'b0;
            end else if (q.size() != 0) begin
                ap = q.pop_front(); ap_valid = 1'b1;
            end else begin
                ap_valid = 1'b0;
            end
            if (ap_valid) begin
                htrans <= 2'b10; haddr <= ap.addr; hwrite <= ap.write;
                hsize <= ap.size;
            end else begin
                htrans <= 2'b00; haddr <= $urandom; hwrite <= $urandom;
                hsize <= 3'b000;
            end
        end else begin
            if (dp_valid) dp_wait++;
            // First ERROR cycle: optionally cancel the pending address phase.
            if (hresp && cancel_on_error && ap_valid) begin
                q.push_front(ap); ap_valid = 1'b0; n_cancel++;
                htrans <= 2'b00;
            end
        end
    end
endmodule
