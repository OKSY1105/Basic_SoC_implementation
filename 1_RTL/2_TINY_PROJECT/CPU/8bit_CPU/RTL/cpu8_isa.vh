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
// Interrupt entry: fixed word address of the handler.
`define CPU8_IRQ_VECTOR 16'h0002
`endif
