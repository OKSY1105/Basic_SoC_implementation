`timescale 1ns/1ps
// 8-bit adaptation of the author's alu_32b.v and ALU_4bit.v.
// 0=AND 1=OR 2=NOR 3=ADD 4=SUB 5=SLT 6=SLTU
module alu (
    input  wire [7:0] i_a,
    input  wire [7:0] i_b,
    input  wire [3:0] i_op,
    output reg  [7:0] o_result,
    output wire       o_zero,
    output reg        o_carry,
    output reg        o_overflow
);
    reg [8:0] r_sum;
    reg [8:0] r_diff;

    always @(*) begin
        r_sum      = {1'b0, i_a} + {1'b0, i_b};
        r_diff     = {1'b0, i_a} + {1'b0, ~i_b} + 9'd1;
        o_result   = 8'h00;
        o_carry    = 1'b0;
        o_overflow = 1'b0;
        case (i_op)
            4'd0: o_result = i_a & i_b;
            4'd1: o_result = i_a | i_b;
            4'd2: o_result = ~(i_a | i_b);
            4'd3: begin
                o_result   = r_sum[7:0];
                o_carry    = r_sum[8];
                o_overflow = (~(i_a[7] ^ i_b[7])) & (i_a[7] ^ r_sum[7]);
            end
            4'd4: begin
                o_result   = r_diff[7:0];
                o_carry    = r_diff[8]; // 1 means no borrow
                o_overflow = (i_a[7] ^ i_b[7]) & (i_a[7] ^ r_diff[7]);
            end
            4'd5: o_result = ($signed(i_a) < $signed(i_b)) ? 8'd1 : 8'd0;
            4'd6: o_result = (i_a < i_b) ? 8'd1 : 8'd0;
            default: o_result = 8'h00;
        endcase
    end
    assign o_zero = (o_result == 8'h00);
endmodule
