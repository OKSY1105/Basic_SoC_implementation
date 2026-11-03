`timescale 1ns/1ps
// APB3 slave model for unit TBs of bridges and APB decoders.
//   - Each transfer waits a random MIN_WAIT..MAX_WAIT ACCESS cycles with
//     PREADY low, then completes with PREADY high.
//   - ERR_EN=1: a transfer whose PADDR[3:0] == 4'hF completes with PSLVERR.
//   - Read data is data_of(PADDR), a pattern that depends on ID.
//   - JUNK=1: outside the ACCESS phase PREADY, PSLVERR and PRDATA are
//     random, so a master that samples them outside ACCESS is caught.
//   - Every completed transfer is appended to log[] (address, direction,
//     data, PSLVERR, wait cycles). Reset drops the transfer in flight.
// Outputs are registered (change only at the rising clock edge).
module apb_slave_model #(
    parameter integer ADDR_W   = 12,
    parameter integer DATA_W   = 8,
    parameter integer ID       = 0,
    parameter integer MIN_WAIT = 0,
    parameter integer MAX_WAIT = 3,
    parameter bit     ERR_EN   = 1'b1,
    parameter bit     JUNK     = 1'b1
) (
    input  wire              clk,
    input  wire              rstn,
    input  wire              psel,
    input  wire              penable,
    input  wire [ADDR_W-1:0] paddr,
    input  wire              pwrite,
    input  wire [DATA_W-1:0] pwdata,
    output reg               pready,
    output reg               pslverr,
    output reg  [DATA_W-1:0] prdata
);
    typedef struct {
        logic [ADDR_W-1:0] addr;
        bit                write;
        logic [DATA_W-1:0] data;            // PWDATA or PRDATA
        bit                err;
        int unsigned       waits;
    } log_t;

    log_t log[$];
    int unsigned n_wait_cycles = 0, n_errors = 0, n_junk_ready = 0;
    int unsigned left = 0, waits = 0;

    function automatic logic [DATA_W-1:0] data_of(input logic [ADDR_W-1:0] a);
        return DATA_W'((a ^ (a >> 8)) + ID * 8'h35);
    endfunction

    task automatic drive_idle();
        if (JUNK) begin
            pready <= $urandom; pslverr <= $urandom; prdata <= $urandom;
        end else begin
            pready <= 1'b0; pslverr <= 1'b0;
        end
    endtask

    task automatic drive_access();             // next cycle is an ACCESS cycle
        if (left != 0) begin
            pready <= 1'b0; pslverr <= $urandom; prdata <= $urandom;
            n_wait_cycles++;
        end else begin
            pready <= 1'b1;
            pslverr <= ERR_EN && (paddr[3:0] == 4'hF);
            prdata <= pwrite ? DATA_W'($urandom) : data_of(paddr);
            if (ERR_EN && (paddr[3:0] == 4'hF)) n_errors++;
        end
    endtask

    initial begin pready = 1'b0; pslverr = 1'b0; prdata = '0; end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            left = 0; pready <= 1'b0; pslverr <= 1'b0;
        end else if (psel && !penable) begin
            // SETUP: the next cycle is the first ACCESS cycle.
            left = $urandom_range(MAX_WAIT, MIN_WAIT); waits = left;
            drive_access();
        end else if (psel && penable && !pready) begin
            if (left != 0) left--;
            drive_access();
        end else begin
            if (psel && penable && pready) begin
                log_t e;
                e.addr = paddr; e.write = pwrite; e.err = pslverr; e.waits = waits;
                e.data = pwrite ? pwdata : prdata;
                log.push_back(e);
            end
            drive_idle();
        end
    end

    // Cycles outside ACCESS with PREADY high (TB coverage).
    always @(negedge clk) if (rstn && !(psel && penable) && pready) n_junk_ready++;
endmodule
