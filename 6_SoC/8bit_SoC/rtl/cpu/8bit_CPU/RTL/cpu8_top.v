`timescale 1ns/1ps
`default_nettype none
`include "cpu8_isa.vh"
// Single-issue IF / ID-EX / MEM-WB pipeline; no forwarding.
// Instruction addresses count 16-bit WORDS; data addresses count BYTES.
// Both ports complete at req && ready on a rising edge. Read data/error
// must be valid then. A memory wrapper must suppress writes on error.
// Instruction requests may be cancelled on reset/older fault/HALT.
// Data requests stay stable until completion, except on reset.
module cpu8_top (
    input wire i_clk, i_rst_n,
    output wire o_i_req,
    output wire [15:0] o_i_addr,
    input wire [15:0] i_i_data,
    input wire i_i_ready, i_i_error,
    output wire o_d_req, o_d_write,
    output wire [15:0] o_d_addr,
    output wire [7:0] o_d_wdata,
    input wire [7:0] i_d_rdata,
    input wire i_d_ready, i_d_error,
    output reg o_halted, o_fault,
    output reg [2:0] o_fault_code,
    output reg [15:0] o_pc,
    output wire [15:0] o_x,
    output wire [3:0] o_flags,
    output wire [31:0] o_registers,
    output wire o_stall,
    output wire [2:0] o_stage_valid,
    output reg o_retire_valid,
    output reg [15:0] o_retire_pc, o_retire_instruction,
    output reg o_retire_reg_write,
    output reg [1:0] o_retire_rd,
    output reg [7:0] o_retire_data
);
    reg [15:0] r_fetch_pc, r_x;
    reg [3:0] r_flags;
    reg r_stop_fetch;

    // IF/ID boundary: the instruction remains here throughout RAW/backpressure.
    reg r_id_valid, r_id_error;
    reg [15:0] r_id_pc, r_id_instruction;
    // ID/MEM boundary: the oldest issued instruction owns the data port.
    reg r_m_valid, r_m_memory, r_m_store, r_m_halt, r_m_fault;
    reg r_m_reg_write, r_m_flags_write, r_m_x_write;
    reg [2:0] r_m_fault_code;
    reg [15:0] r_m_pc, r_m_instruction, r_m_next_pc, r_m_address, r_m_x_data;
    reg [1:0] r_m_rd;
    reg [7:0] r_m_result, r_m_store_data;
    reg [3:0] r_m_flags;

    wire [5:0] w_opcode;
    wire [1:0] w_rd, w_rs;
    wire w_legal,w_read_rd,w_read_rs,w_read_flags,w_read_x;
    wire w_reg_write,w_flags_write,w_x_write,w_memory,w_store,w_branch,w_halt;
    wire [7:0] w_a,w_b,w_alu_result;
    wire [3:0] w_alu_flags;
    wire w_m_done=r_m_valid && (!r_m_memory || i_d_ready);
    wire w_m_error=r_m_fault || (r_m_memory && i_d_error);
    wire w_m_terminal=w_m_done && (w_m_error || r_m_halt);
    wire w_wb_write=w_m_done && !w_m_error && r_m_reg_write && !o_halted;
    wire [7:0] w_wb_data=r_m_memory ? i_d_rdata : r_m_result;

    cpu8_decoder u_decoder (
        .i_instruction(r_id_instruction),.o_opcode(w_opcode),.o_rd(w_rd),.o_rs(w_rs),
        .o_legal(w_legal),.o_read_rd(w_read_rd),.o_read_rs(w_read_rs),
        .o_read_flags(w_read_flags),.o_read_x(w_read_x),
        .o_write_reg(w_reg_write),.o_write_flags(w_flags_write),
        .o_write_x(w_x_write),.o_memory(w_memory),.o_store(w_store),
        .o_branch(w_branch),.o_halt(w_halt)
    );
    cpu8_regfile u_regfile (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_ra(w_rd),.i_rb(w_rs),
        .i_wa(r_m_rd),.i_wdata(w_wb_data),.i_we(w_wb_write),
        .o_a(w_a),.o_b(w_b),.o_registers(o_registers)
    );
    cpu8_alu u_alu (
        .i_a(w_a),.i_b(w_b),.i_opcode(w_opcode),.i_carry(r_flags[1]),
        .o_result(w_alu_result),.o_flags(w_alu_flags)
    );

    wire w_gpr_hazard=r_m_valid && r_m_reg_write &&
        ((w_read_rd && w_rd==r_m_rd) || (w_read_rs && w_rs==r_m_rd));
    wire w_flags_hazard=r_m_valid && r_m_flags_write && w_read_flags;
    wire w_x_hazard=r_m_valid && r_m_x_write && w_read_x;
    wire w_hazard=w_gpr_hazard || w_flags_hazard || w_x_hazard;
    wire w_id_fault=r_id_error || !w_legal;
    wire w_id_issue=r_id_valid && (!r_m_valid || w_m_done) && !w_hazard &&
        !w_m_terminal && !o_halted;
    wire w_take_branch=w_branch &&
        ((w_opcode==`CPU8_OP_JMP) ||
         (w_opcode==`CPU8_OP_JZ && r_flags[3]) ||
         (w_opcode==`CPU8_OP_JC && r_flags[1]));
    wire [15:0] w_sequential_pc=r_id_pc+16'd1;
    wire [15:0] w_branch_pc=w_sequential_pc+
        {{8{r_id_instruction[7]}},r_id_instruction[7:0]};
    wire w_redirect=w_id_issue && !w_id_fault && w_take_branch;
    wire w_stop_issue=w_id_issue && (w_id_fault || w_halt);
    assign o_i_req=i_rst_n && !o_halted && !r_stop_fetch && !w_m_terminal &&
        (!r_id_valid || w_id_issue) && !w_redirect && !w_stop_issue;
    assign o_i_addr=r_fetch_pc;
    wire w_fetch=o_i_req && i_i_ready;

    assign o_d_req=i_rst_n && !o_halted && r_m_valid && r_m_memory && !r_m_fault;
    assign o_d_write=r_m_store;
    assign o_d_addr=r_m_address;
    assign o_d_wdata=r_m_store_data;
    assign o_x=r_x;
    assign o_flags=r_flags;
    assign o_stall=r_id_valid && !w_id_issue && !o_halted && !w_m_terminal;
    assign o_stage_valid={r_m_valid,r_id_valid,o_i_req};

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_fetch_pc<=16'b0; r_x<=16'b0; r_flags<=4'b0; r_stop_fetch<=1'b0;
            r_id_valid<=1'b0; r_id_error<=1'b0;
            r_id_pc<=16'b0; r_id_instruction<=16'b0;
            r_m_valid<=1'b0; r_m_memory<=1'b0; r_m_store<=1'b0;
            r_m_halt<=1'b0; r_m_fault<=1'b0; r_m_fault_code<=3'b0;
            r_m_reg_write<=1'b0; r_m_flags_write<=1'b0; r_m_x_write<=1'b0;
            r_m_pc<=16'b0; r_m_instruction<=16'b0; r_m_next_pc<=16'b0;
            r_m_address<=16'b0; r_m_x_data<=16'b0; r_m_rd<=2'b0;
            r_m_result<=8'b0; r_m_store_data<=8'b0; r_m_flags<=4'b0;
            o_halted<=1'b0; o_fault<=1'b0; o_fault_code<=3'b0; o_pc<=16'b0;
            o_retire_valid<=1'b0; o_retire_pc<=16'b0; o_retire_instruction<=16'b0;
            o_retire_reg_write<=1'b0; o_retire_rd<=2'b0; o_retire_data<=8'b0;
        end else begin
            o_retire_valid<=1'b0; o_retire_reg_write<=1'b0;
            if (w_m_done && !o_halted) begin
                r_m_valid<=1'b0;
                if (w_m_error) begin
                    o_halted<=1'b1; o_fault<=1'b1;
                    o_fault_code<=r_m_fault ? r_m_fault_code : 3'd3;
                    o_pc<=r_m_pc;
                end else begin
                    o_pc<=r_m_next_pc;
                    if (r_m_flags_write) r_flags<=r_m_flags;
                    if (r_m_x_write) r_x<=r_m_x_data;
                    o_retire_valid<=1'b1;
                    o_retire_pc<=r_m_pc;
                    o_retire_instruction<=r_m_instruction;
                    o_retire_reg_write<=r_m_reg_write;
                    o_retire_rd<=r_m_rd;
                    o_retire_data<=w_wb_data;
                    if (r_m_halt) o_halted<=1'b1;
                end
            end
            if (w_m_terminal) begin
                r_id_valid<=1'b0; r_stop_fetch<=1'b1;
            end else if (!o_halted) begin
                if (w_id_issue) begin
                    r_id_valid<=1'b0; r_m_valid<=1'b1;
                    r_m_pc<=r_id_pc; r_m_instruction<=r_id_instruction;
                    r_m_fault<=w_id_fault;
                    r_m_fault_code<=r_id_error ? 3'd2 : 3'd1;
                    r_m_halt<=w_halt && !w_id_fault;
                    r_m_reg_write<=w_reg_write && !w_id_fault;
                    r_m_flags_write<=w_flags_write && !w_id_fault;
                    r_m_x_write<=w_x_write && !w_id_fault;
                    r_m_memory<=w_memory && !w_id_fault;
                    r_m_store<=w_store && !w_id_fault;
                    r_m_rd<=w_rd;
                    r_m_address<=r_x; r_m_store_data<=w_a;
                    r_m_flags<=w_alu_flags;
                    r_m_next_pc<=w_take_branch ? w_branch_pc : w_sequential_pc;
                    case (w_opcode)
                        `CPU8_OP_LDI: r_m_result<=r_id_instruction[7:0];
                        `CPU8_OP_MOV: r_m_result<=w_b;
                        default: r_m_result<=w_alu_result;
                    endcase
                    case (w_opcode)
                        `CPU8_OP_LDXL: r_m_x_data<={r_x[15:8],r_id_instruction[7:0]};
                        `CPU8_OP_LDXH: r_m_x_data<={r_id_instruction[7:0],r_x[7:0]};
                        default: r_m_x_data<=r_x+16'd1;
                    endcase
                    if (w_stop_issue) r_stop_fetch<=1'b1;
                    if (w_redirect) r_fetch_pc<=w_branch_pc;
                end
                if (w_fetch) begin
                    r_id_valid<=1'b1; r_id_pc<=r_fetch_pc;
                    r_id_instruction<=i_i_data; r_id_error<=i_i_error;
                    r_fetch_pc<=r_fetch_pc+16'd1;
                end
            end
        end
    end
endmodule
`default_nettype wire
