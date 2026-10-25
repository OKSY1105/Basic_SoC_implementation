`timescale 1ns/1ps
// Modified from the author's FSM state/next-state coding style.
// Sequential instruction/data access over ONE external byte-wide interface.
module fsm (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire       i_mem_ready,
    input  wire       i_load,
    input  wire       i_store,
    output reg [2:0]  o_state
);
    localparam FETCH_HI   = 3'd0;
    localparam FETCH_LO   = 3'd1;
    localparam DECODE     = 3'd2;
    localparam EXECUTE    = 3'd3;
    localparam MEM_ACCESS = 3'd4;
    localparam WRITEBACK  = 3'd5;

    reg [2:0] r_next_state;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) o_state <= FETCH_HI;
        else          o_state <= r_next_state;
    end
    always @(*) begin
        r_next_state = o_state;
        case (o_state)
            FETCH_HI:   if (i_mem_ready) r_next_state = FETCH_LO;
            FETCH_LO:   if (i_mem_ready) r_next_state = DECODE;
            DECODE:     r_next_state = EXECUTE;
            EXECUTE:    r_next_state = (i_load || i_store) ? MEM_ACCESS : WRITEBACK;
            MEM_ACCESS: if (i_mem_ready) r_next_state = WRITEBACK;
            WRITEBACK:  r_next_state = FETCH_HI;
            default:    r_next_state = FETCH_HI;
        endcase
    end
endmodule
