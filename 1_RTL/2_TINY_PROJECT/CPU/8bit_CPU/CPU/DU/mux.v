`timescale 1ns/1ps
// Reusable 4:1 MUX, sized for 8-bit datapath or 3-bit register address.
module mux #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] i_d0,
    input  wire [WIDTH-1:0] i_d1,
    input  wire [WIDTH-1:0] i_d2,
    input  wire [WIDTH-1:0] i_d3,
    input  wire [1:0]       i_sel,
    output reg  [WIDTH-1:0] o_y
);
    always @(*) begin
        case (i_sel)
            2'd0: o_y = i_d0;
            2'd1: o_y = i_d1;
            2'd2: o_y = i_d2;
            2'd3: o_y = i_d3;
            default: o_y = {WIDTH{1'b0}};
        endcase
    end
endmodule
