`timescale 1ns/1ps
// 16-bit custom MIPS-style ISA, 17 operations matching reference repository.
// R: {op=0 [15:12],rs[11:9],rt[8:6],rd[5:3],fn[2:0]}
// I: {op [15:12],rs[11:9],rt[8:6],imm6[5:0]}
// J: {op=10 [15:12],reserved[11:8],target[7:0]}
module instruction_decoder (
    input  wire [15:0] i_instr,
    output reg         o_valid,
    output reg         o_reg_we,
    output reg         o_reg_dst,
    output reg         o_wb_mem,
    output reg  [1:0]  o_alu_src,
    output reg  [3:0]  o_alu_op,
    output reg         o_load,
    output reg         o_store,
    output reg         o_branch,
    output reg         o_jump
);
    wire [3:0] w_opcode = i_instr[15:12];
    wire [2:0] w_funct  = i_instr[2:0];
    always @(*) begin
        o_valid   = 1'b1;
        o_reg_we  = 1'b0;
        o_reg_dst = 1'b0;
        o_wb_mem  = 1'b0;
        o_alu_src = 2'd1;  // reg B
        o_alu_op  = 4'd3;  // ADD
        o_load    = 1'b0;
        o_store   = 1'b0;
        o_branch  = 1'b0;
        o_jump    = 1'b0;
        case (w_opcode)
            4'h0: begin
                o_reg_we  = 1'b1;
                o_reg_dst = 1'b1;  // rd
                case (w_funct)
                    3'd1: o_alu_op = 4'd0; // AND
                    3'd2: o_alu_op = 4'd1; // OR
                    3'd3: o_alu_op = 4'd2; // NOR
                    3'd4: o_alu_op = 4'd3; // ADD
                    3'd5: o_alu_op = 4'd4; // SUB
                    3'd6: o_alu_op = 4'd5; // SLT
                    3'd7: o_alu_op = 4'd6; // SLTU
                    default: begin o_valid = 1'b0; o_reg_we = 1'b0; end
                endcase
            end
            4'h1: begin o_reg_we=1'b1; o_alu_src=2'd2; o_alu_op=4'd0; end // ANDI
            4'h2: begin o_reg_we=1'b1; o_alu_src=2'd2; o_alu_op=4'd1; end // ORI
            4'h3: begin o_reg_we=1'b1; o_alu_src=2'd3; o_alu_op=4'd3; end // ADDI
            4'h4: begin o_reg_we=1'b1; o_alu_src=2'd2; o_alu_op=4'd3; end // ADDUI
            4'h5: begin o_reg_we=1'b1; o_alu_src=2'd3; o_alu_op=4'd5; end // SLTI
            4'h6: begin o_reg_we=1'b1; o_alu_src=2'd2; o_alu_op=4'd6; end // SLTUI
            4'h7: begin o_reg_we=1'b1; o_alu_src=2'd2; o_alu_op=4'd3; o_wb_mem=1'b1; o_load=1'b1; end // LW
            4'h8: begin o_alu_src=2'd2; o_alu_op=4'd3; o_store=1'b1; end // SW
            4'h9: begin o_alu_src=2'd1; o_alu_op=4'd4; o_branch=1'b1; end // BEQ
            4'hA: begin o_jump=1'b1; end // J
            default: o_valid=1'b0; // unassigned opcode: no-op
        endcase
    end
endmodule
