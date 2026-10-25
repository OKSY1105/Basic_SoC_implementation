`timescale 1ns/1ps
module cu (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [15:0] i_instruction,
    input  wire        i_alu_zero,
    input  wire        i_mem_ready,
    output reg         o_mem_req,
    output reg         o_mem_we,
    output reg  [1:0]  o_mem_addr_sel,
    output reg         o_ir_hi_we,
    output reg         o_ir_lo_we,
    output reg         o_load_capture,
    output reg         o_pc_we,
    output reg  [1:0]  o_pc_sel,
    output reg         o_reg_we,
    output wire        o_reg_dst,
    output wire        o_wb_mem,
    output wire [1:0]  o_alu_src,
    output wire [3:0]  o_alu_op
);
    localparam FETCH_HI   = 3'd0;
    localparam FETCH_LO   = 3'd1;
    localparam DECODE     = 3'd2;
    localparam EXECUTE    = 3'd3;
    localparam MEM_ACCESS = 3'd4;
    localparam WRITEBACK  = 3'd5;

    wire w_valid, w_reg_we, w_load, w_store, w_branch, w_jump;
    wire [2:0] w_state;

    instruction_decoder u_decoder (
        .i_instr(i_instruction),
        .o_valid(w_valid),
        .o_reg_we(w_reg_we),
        .o_reg_dst(o_reg_dst),
        .o_wb_mem(o_wb_mem),
        .o_alu_src(o_alu_src),
        .o_alu_op(o_alu_op),
        .o_load(w_load),
        .o_store(w_store),
        .o_branch(w_branch),
        .o_jump(w_jump)
    );
    fsm u_fsm (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_mem_ready(i_mem_ready),
        .i_load(w_load), .i_store(w_store),
        .o_state(w_state)
    );

    always @(*) begin
        o_mem_req      = 1'b0;
        o_mem_we       = 1'b0;
        o_mem_addr_sel = 2'd0;
        o_ir_hi_we     = 1'b0;
        o_ir_lo_we     = 1'b0;
        o_load_capture = 1'b0;
        o_pc_we        = 1'b0;
        o_pc_sel       = 2'd0;
        o_reg_we       = 1'b0;
        case (w_state)
            FETCH_HI: begin
                o_mem_req      = 1'b1;
                o_mem_addr_sel = 2'd0; // PC
                o_ir_hi_we     = i_mem_ready;
            end
            FETCH_LO: begin
                o_mem_req      = 1'b1;
                o_mem_addr_sel = 2'd1; // PC+1
                o_ir_lo_we     = i_mem_ready;
            end
            MEM_ACCESS: if (w_valid) begin
                o_mem_req      = 1'b1;
                o_mem_addr_sel = 2'd2; // ALU computed data address
                o_mem_we       = w_store;
                o_load_capture = w_load && i_mem_ready;
            end
            WRITEBACK: begin
                o_reg_we = w_valid && w_reg_we;
                o_pc_we  = 1'b1;
                if (w_jump)                    o_pc_sel = 2'd2;
                else if (w_branch && i_alu_zero) o_pc_sel = 2'd1;
            end
            default: begin end
        endcase
    end
endmodule
