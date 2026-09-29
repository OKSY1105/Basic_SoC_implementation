//debug point2
`include "include.v"
module Activation_Unit #(
    parameter dataWidth = 8
)(
    input clk,
    input signed [`accWidth-1:0] psum_in, 
    input [2*dataWidth-1:0] bias_in, 
    input act_sel, 
    output reg [dataWidth-1:0] out
);
    wire signed [`accWidth:0] bias_add_res;
    reg signed [2*dataWidth-1:0] sum_saturated;
    
    assign bias_add_res = $signed(psum_in) + $signed(bias_in);
    
    always @(*) begin
        if (bias_add_res > $signed({1'b0, {(2*dataWidth-1){1'b1}}})) // > Max Positive
            sum_saturated = {1'b0, {(2*dataWidth-1){1'b1}}};
        else if (bias_add_res < $signed({1'b1, {(2*dataWidth-1){1'b0}}})) // < Min Negative
            sum_saturated = {1'b1, {(2*dataWidth-1){1'b0}}};
        else
            sum_saturated = bias_add_res[2*dataWidth-1:0];
    end
    wire [dataWidth-1:0] sig_out;
    wire [dataWidth-1:0] relu_out;
    Sig_ROM #(
        .inWidth(`sigmoidSize), 
        .dataWidth(dataWidth)
    ) sig_inst (
        .clk(clk),
        .x(sum_saturated[2*dataWidth-1 -: `sigmoidSize]), 
        .out(sig_out)
    );
    ReLU #(
        .inWidth(`accWidth+1),
        .dataWidth(dataWidth),
        .weightIntWidth(`accWidth + 1 - (2*dataWidth) + `weightIntWidth - 2)
    ) relu_inst (
        .clk(clk),
        .x(bias_add_res),
        .out(relu_out)
    );
    always @(*) begin
        if (act_sel == 1'b0) 
            out = sig_out;
        else 
            out = relu_out;
    end
endmodule