`timescale 1ns/1ps
`default_nettype none
`include "cpu8_isa.vh"
// Separate from the preserved MIPS decoder: 6/2/8 ISA, four writable GPRs,
// 20 instructions (17 + EI/DI/RETI) + v2 stage 1 stack/subroutine group
// (PUSH, POP, PUSH LRx, POP LRx, LSPL, LSPH, CALL a12, RET).
module cpu8_decoder (
    input wire [15:0] i_instruction,
    output wire [5:0] o_opcode,
    output wire [1:0] o_rd, o_rs,
    output reg o_legal, o_read_rd, o_read_rs, o_read_flags, o_read_x,
    output reg o_write_reg, o_write_flags, o_write_x,
    output reg o_memory, o_store, o_branch, o_halt,
    output reg o_ei, o_di, o_reti,
    // v2: SP/LR read and write, data address from SP, PUSH LRx data from LR,
    // POP LRx data into LR, CALL and RET.
    output reg o_read_sp, o_write_sp, o_read_lr, o_write_lr,
    output reg o_sp_addr, o_lr_store, o_lr_load, o_call, o_ret
);
    assign o_opcode = i_instruction[15:10];
    assign o_rd = i_instruction[9:8];
    assign o_rs = i_instruction[1:0];
    always @(*) begin
        o_legal=1'b0;
        o_read_rd=1'b0; o_read_rs=1'b0; o_read_flags=1'b0; o_read_x=1'b0;
        o_write_reg=1'b0; o_write_flags=1'b0; o_write_x=1'b0;
        o_memory=1'b0; o_store=1'b0; o_branch=1'b0; o_halt=1'b0;
        o_ei=1'b0; o_di=1'b0; o_reti=1'b0;
        o_read_sp=1'b0; o_write_sp=1'b0; o_read_lr=1'b0; o_write_lr=1'b0;
        o_sp_addr=1'b0; o_lr_store=1'b0; o_lr_load=1'b0; o_call=1'b0; o_ret=1'b0;
        if (i_instruction[15:12]==`CPU8_CALL_PREFIX) begin
            // CALL a12: LR <- PC+1, PC <- a12. Every encoding is legal.
            o_legal=1'b1; o_call=1'b1; o_write_lr=1'b1;
        end else
        case (o_opcode)
            `CPU8_OP_HALT: begin
                o_legal=(i_instruction[9:0]==10'b0); o_halt=1'b1;
            end
            `CPU8_OP_LDI: begin o_legal=1'b1; o_write_reg=1'b1; end
            `CPU8_OP_MOV: begin
                o_legal=(i_instruction[7:2]==6'b0);
                o_read_rs=1'b1; o_write_reg=1'b1;
            end
            `CPU8_OP_LD, `CPU8_OP_ST: begin
                o_legal=(i_instruction[7:0]==8'b0);
                o_read_x=1'b1; o_memory=1'b1;
                o_store=(o_opcode==`CPU8_OP_ST);
                o_read_rd=(o_opcode==`CPU8_OP_ST);
                o_write_reg=(o_opcode==`CPU8_OP_LD);
            end
            `CPU8_OP_LDXL, `CPU8_OP_LDXH, `CPU8_OP_INX: begin
                o_legal=(i_instruction[9:8]==2'b0);
                if (o_opcode==`CPU8_OP_INX)
                    o_legal=o_legal && (i_instruction[7:0]==8'b0);
                o_read_x=1'b1; o_write_x=1'b1;
            end
            `CPU8_OP_ADD, `CPU8_OP_ADC, `CPU8_OP_SUB, `CPU8_OP_SBC,
            `CPU8_OP_CMP, `CPU8_OP_AND: begin
                o_legal=(i_instruction[7:2]==6'b0);
                o_read_rd=1'b1; o_read_rs=1'b1; o_write_flags=1'b1;
                o_write_reg=(o_opcode!=`CPU8_OP_CMP);
                o_read_flags=(o_opcode==`CPU8_OP_ADC || o_opcode==`CPU8_OP_SBC);
            end
            `CPU8_OP_JMP, `CPU8_OP_JZ, `CPU8_OP_JC: begin
                o_legal=(i_instruction[9:8]==2'b0); o_branch=1'b1;
                o_read_flags=(o_opcode!=`CPU8_OP_JMP);
            end
            // Interrupt control. RETI is legal only inside the handler; the
            // top level adds that check.
            `CPU8_OP_EI: begin o_legal=(i_instruction[9:0]==10'b0); o_ei=1'b1; end
            `CPU8_OP_DI: begin o_legal=(i_instruction[9:0]==10'b0); o_di=1'b1; end
            `CPU8_OP_RETI: begin o_legal=(i_instruction[9:0]==10'b0); o_reti=1'b1; end
            // Stack: one byte at SP-1 (push) or SP (pop), like ST/LD with X.
            `CPU8_OP_PUSH, `CPU8_OP_POP: begin
                o_legal=(i_instruction[7:0]==8'b0);
                o_memory=1'b1; o_sp_addr=1'b1; o_read_sp=1'b1; o_write_sp=1'b1;
                o_store=(o_opcode==`CPU8_OP_PUSH);
                o_read_rd=(o_opcode==`CPU8_OP_PUSH);
                o_write_reg=(o_opcode==`CPU8_OP_POP);
            end
            // LR byte r (0: low, 1: high) to/from the stack.
            `CPU8_OP_PUSHLR, `CPU8_OP_POPLR: begin
                o_legal=(i_instruction[9]==1'b0) && (i_instruction[7:0]==8'b0);
                o_memory=1'b1; o_sp_addr=1'b1; o_read_sp=1'b1; o_write_sp=1'b1;
                o_read_lr=1'b1;
                o_store=(o_opcode==`CPU8_OP_PUSHLR);
                o_lr_store=(o_opcode==`CPU8_OP_PUSHLR);
                o_lr_load=(o_opcode==`CPU8_OP_POPLR);
                o_write_lr=(o_opcode==`CPU8_OP_POPLR);
            end
            `CPU8_OP_LSPL, `CPU8_OP_LSPH: begin
                o_legal=(i_instruction[9:8]==2'b0);
                o_read_sp=1'b1; o_write_sp=1'b1;
            end
            `CPU8_OP_RET: begin
                o_legal=(i_instruction[9:0]==10'b0); o_read_lr=1'b1; o_ret=1'b1;
            end
            default: begin end
        endcase
    end
endmodule
`default_nettype wire
