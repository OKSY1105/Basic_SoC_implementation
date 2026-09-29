`include "include.v"
//debug point1
module PE #(
    parameter dataWidth = 8
)(
    input                   clk,
    input                   rst, 
    input                   en,  
    input [dataWidth-1:0]   a,   
    input [dataWidth-1:0]   b,   
    output [`accWidth-1:0] psum,
    output [`accWidth-1:0] debug_mul 
);
    reg [`accWidth-1:0] sum;
    wire [`accWidth-1:0] mul;
    wire [2*dataWidth:0]   comboAdd; 
    assign mul = $signed({1'b0, a}) * $signed(b);
    assign debug_mul = mul;
    
    always @(posedge clk) begin
        if (rst) begin
            sum <= 0;
        end else if (en) begin
            sum <= sum + mul; 
        end
    end
    assign psum = sum;
endmodule