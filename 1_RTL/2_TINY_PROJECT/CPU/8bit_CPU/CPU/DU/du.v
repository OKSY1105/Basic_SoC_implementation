`timescale 1ns/1ps
module du (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [7:0]  i_mem_rdata,
    input  wire        i_ir_hi_we,
    input  wire        i_ir_lo_we,
    input  wire        i_load_capture,
    input  wire        i_pc_we,
    input  wire [1:0]  i_pc_sel,
    input  wire        i_reg_we,
    input  wire        i_reg_dst,
    input  wire        i_wb_mem,
    input  wire [1:0]  i_alu_src,
    input  wire [3:0]  i_alu_op,
    input  wire [1:0]  i_mem_addr_sel,
    output wire [15:0] o_instruction,
    output wire        o_alu_zero,
    output wire [7:0]  o_mem_addr,
    output wire [7:0]  o_mem_wdata
);
    wire [7:0] w_pc, w_pc_inc, w_branch_target, w_jump_target;
    wire [7:0] w_pc_target, w_alu_a, w_rf_b, w_alu_b;
    wire [7:0] w_imm_unsigned, w_imm_signed, w_alu_result;
    wire [7:0] w_writeback;
    wire [2:0] w_write_addr;
    wire       w_carry, w_overflow;
    reg  [7:0] r_load_data;

    ir u_ir (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_hi_we(i_ir_hi_we), .i_lo_we(i_ir_lo_we),
        .i_data(i_mem_rdata), .o_instruction(o_instruction)
    );

    ext u_ext (
        .i_imm(o_instruction[5:0]),
        .o_unsigned(w_imm_unsigned), .o_signed(w_imm_signed)
    );

    mux #(.WIDTH(3)) u_dst_mux (
        .i_d0(o_instruction[8:6]), .i_d1(o_instruction[5:3]),
        .i_d2(3'd0), .i_d3(3'd0),
        .i_sel({1'b0,i_reg_dst}), .o_y(w_write_addr)
    );

    irf u_irf (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_ra(o_instruction[11:9]), .i_rb(o_instruction[8:6]),
        .i_wa(w_write_addr), .i_wdata(w_writeback), .i_we(i_reg_we),
        .o_a(w_alu_a), .o_b(w_rf_b)
    );

    mux #(.WIDTH(8)) u_operand_mux (
        .i_d0(8'h00), .i_d1(w_rf_b),
        .i_d2(w_imm_unsigned), .i_d3(w_imm_signed),
        .i_sel(i_alu_src), .o_y(w_alu_b)
    );

    alu u_alu (
        .i_a(w_alu_a), .i_b(w_alu_b), .i_op(i_alu_op),
        .o_result(w_alu_result), .o_zero(o_alu_zero),
        .o_carry(w_carry), .o_overflow(w_overflow)
    );

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_load_data <= 8'h00;
        else if (i_load_capture)
            r_load_data <= i_mem_rdata;
    end

    mux #(.WIDTH(8)) u_writeback_mux (
        .i_d0(w_alu_result), .i_d1(r_load_data),
        .i_d2(8'h00), .i_d3(8'h00),
        .i_sel({1'b0,i_wb_mem}), .o_y(w_writeback)
    );

    assign w_pc_inc = w_pc + 8'd2;
    // Sign-extended six-bit branch displacement counts 16-bit instructions.
    // Target = current byte PC + 2 + (signext(imm6) << 1).
    assign w_branch_target = w_pc_inc + (w_imm_signed << 1);
    // J target is absolute BYTE address, low eight bits of 12-bit target field.
    assign w_jump_target = o_instruction[7:0];

    mux #(.WIDTH(8)) u_pc_target_mux (
        .i_d0(w_pc_inc), .i_d1(w_branch_target),
        .i_d2(w_jump_target), .i_d3(8'h00),
        .i_sel(i_pc_sel), .o_y(w_pc_target)
    );
    pc u_pc (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_en(i_pc_we), .i_load(i_pc_sel != 2'd0),
        .i_load_addr(w_pc_target), .o_pc(w_pc)
    );

    mux #(.WIDTH(8)) u_mem_address_mux (
        .i_d0(w_pc), .i_d1(w_pc + 8'd1),
        .i_d2(w_alu_result), .i_d3(8'h00),
        .i_sel(i_mem_addr_sel), .o_y(o_mem_addr)
    );
    assign o_mem_wdata = w_rf_b;
endmodule
