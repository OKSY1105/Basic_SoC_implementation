`timescale 1ns/1ps
// 6-bit immediate => 8-bit zero/sign extension.
module ext (
    input  wire [5:0] i_imm,
    output wire [7:0] o_unsigned,
    output wire [7:0] o_signed
);
    assign o_unsigned = {2'b00, i_imm};
    assign o_signed   = {{2{i_imm[5]}}, i_imm};
endmodule
