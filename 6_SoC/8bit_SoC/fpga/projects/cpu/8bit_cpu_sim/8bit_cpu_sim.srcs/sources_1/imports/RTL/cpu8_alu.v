`timescale 1ns/1ps
`default_nettype none
`include "cpu8_isa.vh"
// Reference: CPU/DU/alu.v; retain 9-bit arithmetic, add carry/borrow inputs.
// Flags are {Z,N,C,V}. For subtraction C=1 means NO borrow.
module cpu8_alu (
    input wire [7:0] i_a, i_b,
    input wire [5:0] i_opcode,
    input wire i_carry,
    output reg [7:0] o_result,
    output reg [3:0] o_flags
);
    reg [8:0] r_wide, r_subtrahend;
    reg r_carry, r_overflow, r_extra;
    always @(*) begin
        r_wide=9'b0; r_subtrahend=9'b0;
        r_carry=1'b0; r_overflow=1'b0; r_extra=1'b0;
        o_result=8'b0;
        case (i_opcode)
            `CPU8_OP_ADD, `CPU8_OP_ADC: begin
                r_extra=(i_opcode==`CPU8_OP_ADC) && i_carry;
                r_wide={1'b0,i_a}+{1'b0,i_b}+{8'b0,r_extra};
                o_result=r_wide[7:0]; r_carry=r_wide[8];
                r_overflow=(!(i_a[7]^i_b[7])) && (i_a[7]^o_result[7]);
            end
            `CPU8_OP_SUB, `CPU8_OP_SBC, `CPU8_OP_CMP: begin
                r_extra=(i_opcode==`CPU8_OP_SBC) && !i_carry;
                r_subtrahend={1'b0,i_b}+{8'b0,r_extra};
                r_wide={1'b0,i_a}-r_subtrahend;
                o_result=r_wide[7:0];
                r_carry=({1'b0,i_a}>=r_subtrahend);
                r_overflow=(i_a[7]^i_b[7]) && (i_a[7]^o_result[7]);
            end
            `CPU8_OP_AND: o_result=i_a&i_b;
            default: o_result=i_b;
        endcase
        o_flags={(o_result==8'b0),o_result[7],r_carry,r_overflow};
    end
endmodule
`default_nettype wire
