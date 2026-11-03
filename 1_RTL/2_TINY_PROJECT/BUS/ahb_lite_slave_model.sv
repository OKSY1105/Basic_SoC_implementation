`timescale 1ns/1ps
// AHB-Lite slave model for unit TBs of decoders, multiplexers and bridges.
//   - Accepts an address phase when HSEL && HTRANS[1] && HREADY.
//   - Each transfer waits a random MIN_WAIT..MAX_WAIT cycles, then completes.
//   - ERR_EN=1: a transfer whose HADDR[3:0] == 4'hF gets a two-cycle ERROR.
//   - Read data is data_of(HADDR), a pattern that depends on ID.
//   - Selected for an IDLE address phase: zero-wait OKAY.
//   - JUNK=1: while this slave does not own the data phase, HREADYOUT, HRESP
//     and HRDATA are random, so a multiplexer that listens to an unselected
//     slave is caught.
//   - Every completed transfer is appended to log[] (address, direction,
//     data, response). Reset drops the transfer in flight but keeps log[].
//   - fails counts protocol violations seen from the bus side (a data phase
//     completed while this slave still held HREADYOUT low).
// Outputs are registered (change only at the rising clock edge).
module ahb_lite_slave_model #(
    parameter integer ADDR_W   = 16,
    parameter integer DATA_W   = 8,
    parameter integer ID       = 0,
    parameter integer MIN_WAIT = 0,
    parameter integer MAX_WAIT = 3,
    parameter bit     ERR_EN   = 1'b1,
    parameter bit     JUNK     = 1'b1
) (
    input  wire              clk,
    input  wire              rstn,
    input  wire              hsel,
    input  wire [ADDR_W-1:0] haddr,
    input  wire [1:0]        htrans,
    input  wire              hwrite,
    input  wire [DATA_W-1:0] hwdata,
    input  wire              hready,        // bus HREADY
    output reg               hreadyout,
    output reg               hresp,
    output reg  [DATA_W-1:0] hrdata
);
    typedef struct {
        logic [ADDR_W-1:0] addr;
        bit                write;
        logic [DATA_W-1:0] data;            // HWDATA or HRDATA
        bit                resp;
    } log_t;

    log_t log[$];
    int unsigned fails = 0;
    int unsigned n_wait_cycles = 0, n_errors = 0, n_junk_low = 0;

    bit seldp = 1'b0;                       // owns the current data phase
    bit dp = 1'b0;                          // ... with a NONSEQ transfer
    bit dp_write, dp_err, err_second;
    logic [ADDR_W-1:0] dp_addr;
    int unsigned dp_left;

    function automatic logic [DATA_W-1:0] data_of(input logic [ADDR_W-1:0] a);
        return DATA_W'((a ^ (a >> 8)) + ID * 8'h35);
    endfunction

    initial begin hreadyout = 1'b1; hresp = 1'b0; hrdata = '0; end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            seldp = 1'b0; dp = 1'b0; err_second = 1'b0;
            hreadyout <= 1'b1; hresp <= 1'b0;
        end else begin
            // 1. The data phase in progress: completes when HREADY is high.
            if (dp) begin
                if (hready) begin
                    log_t e;
                    if (!hreadyout) begin
                        fails++;
                        $display("FAIL slave%0d: data phase ended while HREADYOUT=0 t=%0t",
                                 ID, $time);
                    end
                    e.addr = dp_addr; e.write = dp_write; e.resp = dp_err;
                    e.data = dp_write ? hwdata : hrdata;
                    log.push_back(e);
                    dp = 1'b0;
                end else if (dp_left != 0) begin
                    dp_left--;
                end else if (dp_err) begin
                    err_second = 1'b1;
                end
            end
            // 2. Address phase: sampled when HREADY is high.
            if (hready) begin
                seldp = hsel;
                if (hsel && htrans[1]) begin
                    dp = 1'b1; dp_addr = haddr; dp_write = hwrite;
                    dp_left = $urandom_range(MAX_WAIT, MIN_WAIT);
                    dp_err = ERR_EN && (haddr[3:0] == 4'hF);
                    err_second = 1'b0;
                end
            end
            // 3. Outputs for the next cycle.
            if (!seldp) begin
                if (JUNK) begin
                    hreadyout <= $urandom; hresp <= $urandom; hrdata <= $urandom;
                end else begin
                    hreadyout <= 1'b1; hresp <= 1'b0;
                end
            end else if (!dp) begin
                hreadyout <= 1'b1; hresp <= 1'b0; hrdata <= $urandom;
            end else if (dp_left != 0) begin
                hreadyout <= 1'b0; hresp <= 1'b0; hrdata <= $urandom;
                n_wait_cycles++;
            end else if (dp_err) begin
                hreadyout <= err_second; hresp <= 1'b1; hrdata <= $urandom;
                if (!err_second) n_errors++;
            end else begin
                hreadyout <= 1'b1; hresp <= 1'b0;
                hrdata <= dp_write ? $urandom : data_of(dp_addr);
            end
        end
    end

    // Cycles in which this unselected slave drove HREADYOUT low (TB coverage).
    always @(negedge clk) if (rstn && !seldp && !hreadyout) n_junk_low++;
endmodule
