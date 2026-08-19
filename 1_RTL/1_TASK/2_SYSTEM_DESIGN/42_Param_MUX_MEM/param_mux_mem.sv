`timescale 1ns / 1ps

module param_mux #(
    parameter N = 8,       // number of inputs
    parameter WIDTH = 32   //  bit width of each input
)(
    i_inputs,        //Input that flattens a two-dimensional array into one dimension
    i_select,     
    o_out        
);

input [N*WIDTH-1:0] i_inputs;        //Input that flattens a two-dimensional array into one dimension
input [$clog2(N)-1:0] i_select;
output [WIDTH-1:0] o_out; 

reg [WIDTH-1:0] o_out;
reg [WIDTH-1:0] r_inputs_array [N-1:0];
integer i;

    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            r_inputs_array[i] = i_inputs[i*WIDTH +: WIDTH];
        end

        o_out = r_inputs_array[i_select];
    end

endmodule


module param_mem #(
    parameter N = 4,               
    parameter DATA_WIDTH = 8      
)(
    i_clk,
    i_addr,
    i_data_in,
    i_write_enable,
    o_data_out
);

input i_clk;
input [N-1:0] i_addr;
input [DATA_WIDTH-1:0] i_data_in;
input i_write_enable;
output o_data_out;

reg [DATA_WIDTH-1:0] o_data_out;
reg [DATA_WIDTH-1:0] r_memory [0:(2**N)-1];


    always @(posedge i_clk) begin
        o_data_out <= r_memory[i_addr];
    end

    always @(posedge i_clk) begin
        if (i_write_enable) begin
            r_memory[i_addr] <= i_data_in;
        end
    end
endmodule



