`timescale 1ns/1ps
// CPU CORE ONLY. No ROM, RAM, Flash, UART or AHB-Lite.
// Single shared, byte-wide external Von Neumann interface.
// Transaction: when req & ready sampled at rising clk edge, one byte transfers.
module cpu_top (
    input  wire       i_clk,
    input  wire       i_rst_n,
    output wire       o_mem_req,
    output wire       o_mem_we,
    output wire [7:0] o_mem_addr,
    output wire [7:0] o_mem_wdata,
    input  wire [7:0] i_mem_rdata,
    input  wire       i_mem_ready
);
    wire [15:0] w_instruction;
    wire w_zero;
    wire w_ir_hi_we, w_ir_lo_we, w_load_capture;
    wire w_pc_we, w_reg_we, w_reg_dst, w_wb_mem;
    wire [1:0] w_pc_sel, w_alu_src, w_mem_addr_sel;
    wire [3:0] w_alu_op;

    cu u_cu (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_instruction(w_instruction), .i_alu_zero(w_zero),
        .i_mem_ready(i_mem_ready),
        .o_mem_req(o_mem_req), .o_mem_we(o_mem_we),
        .o_mem_addr_sel(w_mem_addr_sel),
        .o_ir_hi_we(w_ir_hi_we), .o_ir_lo_we(w_ir_lo_we),
        .o_load_capture(w_load_capture),
        .o_pc_we(w_pc_we), .o_pc_sel(w_pc_sel),
        .o_reg_we(w_reg_we), .o_reg_dst(w_reg_dst),
        .o_wb_mem(w_wb_mem), .o_alu_src(w_alu_src), .o_alu_op(w_alu_op)
    );

    du u_du (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_mem_rdata(i_mem_rdata),
        .i_ir_hi_we(w_ir_hi_we), .i_ir_lo_we(w_ir_lo_we),
        .i_load_capture(w_load_capture),
        .i_pc_we(w_pc_we), .i_pc_sel(w_pc_sel),
        .i_reg_we(w_reg_we), .i_reg_dst(w_reg_dst),
        .i_wb_mem(w_wb_mem),
        .i_alu_src(w_alu_src), .i_alu_op(w_alu_op),
        .i_mem_addr_sel(w_mem_addr_sel),
        .o_instruction(w_instruction), .o_alu_zero(w_zero),
        .o_mem_addr(o_mem_addr), .o_mem_wdata(o_mem_wdata)
    );
endmodule
