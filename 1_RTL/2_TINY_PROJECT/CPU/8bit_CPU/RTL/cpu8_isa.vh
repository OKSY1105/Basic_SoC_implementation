`ifndef CPU8_ISA_VH
`define CPU8_ISA_VH
`define CPU8_OP_HALT 6'h01
`define CPU8_OP_LDI  6'h02
`define CPU8_OP_MOV  6'h03
`define CPU8_OP_LD   6'h04
`define CPU8_OP_ST   6'h05
`define CPU8_OP_LDXL 6'h06
`define CPU8_OP_LDXH 6'h07
`define CPU8_OP_INX  6'h08
`define CPU8_OP_ADD  6'h09
`define CPU8_OP_ADC  6'h0a
`define CPU8_OP_SUB  6'h0b
`define CPU8_OP_CMP  6'h0c
`define CPU8_OP_AND  6'h0d
`define CPU8_OP_JMP  6'h14
`define CPU8_OP_JZ   6'h15
`define CPU8_OP_JC   6'h17
`define CPU8_OP_SBC  6'h1a
`define CPU8_OP_EI   6'h18
`define CPU8_OP_DI   6'h19
`define CPU8_OP_RETI 6'h1b
// v2 stage 1: stack (SP) and subroutines (link register LR), per register bank.
`define CPU8_OP_PUSH   6'h0e
`define CPU8_OP_POP    6'h0f
`define CPU8_OP_RET    6'h10
`define CPU8_OP_LSPL   6'h11
`define CPU8_OP_LSPH   6'h12
`define CPU8_OP_PUSHLR 6'h13
`define CPU8_OP_POPLR  6'h16
// CALL a12 uses opcodes 6'h20..6'h23: instruction[15:12]==4'b1000,
// target word address instruction[11:0].
`define CPU8_CALL_PREFIX 4'b1000
// Interrupt entry: fixed word address of the handler.
`define CPU8_IRQ_VECTOR 16'h0002
`endif
