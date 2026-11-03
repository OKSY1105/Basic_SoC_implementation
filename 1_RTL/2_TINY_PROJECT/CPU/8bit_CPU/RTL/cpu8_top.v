`timescale 1ns/1ps
`default_nettype none
`include "cpu8_isa.vh"
// Single-issue IF / ID-EX / MEM-WB pipeline; no forwarding.
// Both memory ports are AMBA AHB-Lite masters: single transfers only
// (HTRANS IDLE/NONSEQ, HBURST SINGLE), HREADY wait, two-cycle ERROR.
// Spec: 6_SoC/8bit_SoC/02_design/cpu_ahb_port.md.
// Instruction port: 16-bit reads at byte address {PC,1'b0}; PC counts words,
//   so HADDR is 17 bits and never aliases. The address phase is the cycle
//   before IF; IF is the data phase. IF/ID plus one skid slot; an address
//   phase is issued only when a slot is guaranteed for its data. Fetches made
//   dead by a branch/HALT/fault are received and discarded.
// Data port: 8-bit byte address X. ID/EX drives the LD/ST address phase and
//   it is accepted on the edge the instruction issues into MEM/WB, which is
//   the data phase. The first ERROR cycle is recorded and the next address
//   phase is cancelled (IDLE) in the second. Slaves suppress writes on ERROR.
// Interrupt (i_irq: level, synchronous to i_clk): taken when IE=1, no
//   handler is running and the ID/EX instruction could issue (MEM/WB empty or
//   completing). That instruction is not executed; its PC goes to EPC and
//   fetch is redirected to CPU8_IRQ_VECTOR (precise: MEM/WB completes, younger
//   fetches are dropped like a taken branch). No new data address phase is
//   driven while an interrupt is pending, and a data address phase already
//   held by HREADY=0 issues first, so no data transfer happens for a dropped
//   instruction. The handler uses register bank 1 (R0-R3, X, FLAGS). RETI
//   (legal only in the handler) returns to EPC with bank 0 and IE=1.
//   EI/DI set IE when they issue. No nesting; HALT is not woken.
module cpu8_top (
    input wire i_clk, i_rst_n,
    output wire [16:0] o_i_haddr,
    output wire [1:0] o_i_htrans,
    output wire [2:0] o_i_hsize, o_i_hburst,
    output wire [3:0] o_i_hprot,
    output wire o_i_hwrite, o_i_hmastlock,
    input wire [15:0] i_i_hrdata,
    input wire i_i_hready, i_i_hresp,
    output wire [15:0] o_d_haddr,
    output wire [1:0] o_d_htrans,
    output wire [2:0] o_d_hsize, o_d_hburst,
    output wire [3:0] o_d_hprot,
    output wire o_d_hwrite, o_d_hmastlock,
    output wire [7:0] o_d_hwdata,
    input wire [7:0] i_d_hrdata,
    input wire i_d_hready, i_d_hresp,
    input wire i_irq,
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
    output reg [7:0] o_retire_data,
    output reg o_retire_bank,           // register bank of the retired instruction
    output wire o_irq_active            // interrupt handler running (bank 1)
);
    localparam [1:0] HTRANS_IDLE=2'b00, HTRANS_NONSEQ=2'b10;
    reg [15:0] r_fetch_pc;
    // X and FLAGS per register bank (0: program, 1: interrupt handler).
    reg [15:0] r_x0, r_x1;
    reg [3:0] r_flags0, r_flags1;
    reg r_stop_fetch;
    // Interrupt state: enable, handler running (= bank in use), return PC.
    reg r_ie, r_bank;
    reg [15:0] r_epc;
    // A data address phase was driven and held by HREADY=0 last cycle.
    reg r_d_held;
    wire [15:0] w_x=r_bank ? r_x1 : r_x0;
    wire [3:0] w_flags=r_bank ? r_flags1 : r_flags0;

    // Instruction address phase held while HREADY=0. The slot rule below only
    // issues an address phase that can wait when IF/ID and skid are empty, so
    // no branch can issue during a hold (asserted in cpu8_ahb_checker).
    reg r_i_hold;
    // Instruction data phase (IF): the fetch in flight and whether it is dead.
    reg r_if_valid, r_if_kill;
    reg [15:0] r_if_pc;
    // IF/ID boundary: the instruction remains here throughout RAW/backpressure.
    reg r_id_valid, r_id_error;
    reg [15:0] r_id_pc, r_id_instruction;
    // Skid slot: a fetch whose data arrives while IF/ID cannot take it.
    reg r_sk_valid, r_sk_error;
    reg [15:0] r_sk_pc, r_sk_instruction;
    // ID/MEM boundary: the oldest issued instruction owns the data phase.
    reg r_m_valid, r_m_memory, r_m_store, r_m_halt, r_m_fault;
    reg r_m_reg_write, r_m_flags_write, r_m_x_write, r_m_bank;
    reg [2:0] r_m_fault_code;
    reg [15:0] r_m_pc, r_m_instruction, r_m_next_pc, r_m_x_data;
    reg [1:0] r_m_rd;
    reg [7:0] r_m_result, r_m_store_data;
    reg [3:0] r_m_flags;
    // First cycle of a data-port ERROR seen; cancels the next address phase.
    reg r_d_err;

    wire [5:0] w_opcode;
    wire [1:0] w_rd, w_rs;
    wire w_legal,w_read_rd,w_read_rs,w_read_flags,w_read_x;
    wire w_reg_write,w_flags_write,w_x_write,w_memory,w_store,w_branch,w_halt;
    wire w_ei,w_di,w_reti;
    wire [7:0] w_a,w_b,w_alu_result;
    wire [3:0] w_alu_flags;
    wire w_m_done=r_m_valid && (!r_m_memory || i_d_hready);
    wire w_m_error=r_m_fault || (r_m_memory && i_d_hresp);
    wire w_m_terminal=w_m_done && (w_m_error || r_m_halt);
    wire w_wb_write=w_m_done && !w_m_error && r_m_reg_write && !o_halted;
    wire [7:0] w_wb_data=r_m_memory ? i_d_hrdata : r_m_result;

    cpu8_decoder u_decoder (
        .i_instruction(r_id_instruction),.o_opcode(w_opcode),.o_rd(w_rd),.o_rs(w_rs),
        .o_legal(w_legal),.o_read_rd(w_read_rd),.o_read_rs(w_read_rs),
        .o_read_flags(w_read_flags),.o_read_x(w_read_x),
        .o_write_reg(w_reg_write),.o_write_flags(w_flags_write),
        .o_write_x(w_x_write),.o_memory(w_memory),.o_store(w_store),
        .o_branch(w_branch),.o_halt(w_halt),
        .o_ei(w_ei),.o_di(w_di),.o_reti(w_reti)
    );
    wire [31:0] w_registers_irq;
    cpu8_regfile u_regfile (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_ra(w_rd),.i_rb(w_rs),
        .i_wa(r_m_rd),.i_rbank(r_bank),.i_wbank(r_m_bank),
        .i_wdata(w_wb_data),.i_we(w_wb_write),
        .o_a(w_a),.o_b(w_b),.o_registers(o_registers),
        .o_registers_irq(w_registers_irq)
    );
    cpu8_alu u_alu (
        .i_a(w_a),.i_b(w_b),.i_opcode(w_opcode),.i_carry(w_flags[1]),
        .o_result(w_alu_result),.o_flags(w_alu_flags)
    );

    wire w_gpr_hazard=r_m_valid && r_m_reg_write &&
        ((w_read_rd && w_rd==r_m_rd) || (w_read_rs && w_rs==r_m_rd));
    wire w_flags_hazard=r_m_valid && r_m_flags_write && w_read_flags;
    wire w_x_hazard=r_m_valid && r_m_x_write && w_read_x;
    wire w_hazard=w_gpr_hazard || w_flags_hazard || w_x_hazard;
    wire w_id_fault=r_id_error || !w_legal || (w_reti && !r_bank);
    // ID/EX may leave this cycle: MEM/WB is empty or completes now.
    wire w_issue_slot=r_id_valid && (!r_m_valid || w_m_done) &&
        !w_m_terminal && !o_halted;
    // Interrupt pending. A held data address phase must issue first.
    wire w_int_ok=i_irq && r_ie && !r_bank && !r_d_held;
    wire w_int_take=w_issue_slot && w_int_ok;
    wire w_id_issue=w_issue_slot && !w_hazard && !w_int_ok;
    wire w_take_branch=w_branch &&
        ((w_opcode==`CPU8_OP_JMP) ||
         (w_opcode==`CPU8_OP_JZ && w_flags[3]) ||
         (w_opcode==`CPU8_OP_JC && w_flags[1]));
    wire [15:0] w_sequential_pc=r_id_pc+16'd1;
    wire [15:0] w_branch_pc=w_sequential_pc+
        {{8{r_id_instruction[7]}},r_id_instruction[7:0]};
    wire w_reti_issue=w_id_issue && !w_id_fault && w_reti;
    // Fetch redirect: taken branch, RETI (to EPC) or interrupt (to vector).
    wire w_redirect=(w_id_issue && !w_id_fault && w_take_branch) ||
        w_reti_issue || w_int_take;
    wire [15:0] w_redirect_pc=w_int_take ? `CPU8_IRQ_VECTOR :
        w_reti_issue ? r_epc : w_branch_pc;
    wire w_stop_issue=w_id_issue && (w_id_fault || w_halt);

    // Instruction port. Every fetch younger than a redirect, HALT/fault issue
    // or terminal MEM/WB completion is dead; its data is never used.
    wire w_kill_fetch=w_redirect || w_stop_issue || w_m_terminal;
    wire w_if_live=r_if_valid && !r_if_kill;
    wire w_if_land=w_if_live && i_i_hready && !w_kill_fetch &&
        !r_stop_fetch && !o_halted;
    wire w_id_free=!r_id_valid || w_id_issue;
    // A new address phase needs a slot for its data even if ID does not issue
    // next cycle: (IF/ID + skid) - issued now + live fetch in flight + 1 <= 2.
    wire [2:0] w_fetch_need=r_id_valid+r_sk_valid+w_if_live+3'd1-w_id_issue;
    wire w_fetch_room=w_redirect || (w_fetch_need<=3'd2);
    wire w_i_new=!o_halted && !r_stop_fetch && !w_stop_issue &&
        !w_m_terminal && !r_d_err && w_fetch_room;
    wire w_i_request=i_rst_n && (r_i_hold || w_i_new);
    wire [15:0] w_i_pc=(!r_i_hold && w_redirect) ? w_redirect_pc : r_fetch_pc;
    wire w_i_accept=w_i_request && i_i_hready;
    // A held address phase is dead if MEM/WB ended the program while it waited.
    wire w_i_dead=r_i_hold && (w_kill_fetch || r_stop_fetch);
    assign o_i_htrans=w_i_request ? HTRANS_NONSEQ : HTRANS_IDLE;
    assign o_i_haddr={w_i_pc,1'b0};
    assign o_i_hsize=3'b001;
    assign o_i_hburst=3'b000;
    assign o_i_hprot=4'b0010;
    assign o_i_hwrite=1'b0;
    assign o_i_hmastlock=1'b0;

    // Data port. The LD/ST in ID/EX drives its address phase from registers
    // only, so it holds through the older data phase and is accepted exactly
    // when the instruction issues. While an interrupt is pending no new
    // address phase starts (the LD/ST will be dropped).
    wire w_m_blocks=r_m_valid && (r_m_halt || r_m_fault);
    wire w_d_request=i_rst_n && !o_halted && r_id_valid && w_memory &&
        !w_id_fault && !w_hazard && !w_m_blocks && !r_d_err && !w_int_ok;
    assign o_d_htrans=w_d_request ? HTRANS_NONSEQ : HTRANS_IDLE;
    assign o_d_haddr=w_x;
    assign o_d_hwrite=w_store;
    assign o_d_hwdata=r_m_store_data;
    assign o_d_hsize=3'b000;
    assign o_d_hburst=3'b000;
    assign o_d_hprot=4'b0011;
    assign o_d_hmastlock=1'b0;
    assign o_x=r_x0;
    assign o_flags=r_flags0;
    assign o_irq_active=r_bank;
    assign o_stall=r_id_valid && !w_id_issue && !w_int_take && !o_halted && !w_m_terminal;
    assign o_stage_valid={r_m_valid,r_id_valid,w_if_live};

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_fetch_pc<=16'b0; r_stop_fetch<=1'b0;
            r_x0<=16'b0; r_x1<=16'b0; r_flags0<=4'b0; r_flags1<=4'b0;
            r_ie<=1'b0; r_bank<=1'b0; r_epc<=16'b0; r_d_held<=1'b0;
            r_m_bank<=1'b0; o_retire_bank<=1'b0;
            r_i_hold<=1'b0;
            r_if_valid<=1'b0; r_if_kill<=1'b0; r_if_pc<=16'b0;
            r_id_valid<=1'b0; r_id_error<=1'b0;
            r_id_pc<=16'b0; r_id_instruction<=16'b0;
            r_sk_valid<=1'b0; r_sk_error<=1'b0;
            r_sk_pc<=16'b0; r_sk_instruction<=16'b0;
            r_d_err<=1'b0;
            r_m_valid<=1'b0; r_m_memory<=1'b0; r_m_store<=1'b0;
            r_m_halt<=1'b0; r_m_fault<=1'b0; r_m_fault_code<=3'b0;
            r_m_reg_write<=1'b0; r_m_flags_write<=1'b0; r_m_x_write<=1'b0;
            r_m_pc<=16'b0; r_m_instruction<=16'b0; r_m_next_pc<=16'b0;
            r_m_x_data<=16'b0; r_m_rd<=2'b0;
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
                    if (r_m_flags_write) begin
                        if (r_m_bank) r_flags1<=r_m_flags; else r_flags0<=r_m_flags;
                    end
                    if (r_m_x_write) begin
                        if (r_m_bank) r_x1<=r_m_x_data; else r_x0<=r_m_x_data;
                    end
                    o_retire_valid<=1'b1;
                    o_retire_bank<=r_m_bank;
                    o_retire_pc<=r_m_pc;
                    o_retire_instruction<=r_m_instruction;
                    o_retire_reg_write<=r_m_reg_write;
                    o_retire_rd<=r_m_rd;
                    o_retire_data<=w_wb_data;
                    if (r_m_halt) o_halted<=1'b1;
                end
            end
            if (r_m_valid && r_m_memory && !i_d_hready && i_d_hresp) r_d_err<=1'b1;
            r_d_held<=w_d_request && !i_d_hready;

            // Instruction address/data phase bookkeeping.
            if (w_i_accept) begin
                r_if_valid<=1'b1; r_if_pc<=w_i_pc; r_if_kill<=w_i_dead;
                r_i_hold<=1'b0; r_fetch_pc<=w_i_pc+16'd1;
            end else begin
                if (i_i_hready) r_if_valid<=1'b0;
                else if (w_kill_fetch) r_if_kill<=1'b1;
                // A waiting address phase (e.g. a branch target) is kept.
                r_i_hold<=w_i_request;
                if (w_i_request) r_fetch_pc<=w_i_pc;
            end

            if (w_m_terminal) begin
                r_id_valid<=1'b0; r_sk_valid<=1'b0; r_stop_fetch<=1'b1;
            end else if (!o_halted) begin
                // Interrupt entry: the ID/EX instruction is dropped (it runs
                // again after RETI) and the handler starts in bank 1.
                if (w_int_take) begin
                    r_epc<=r_id_pc; r_bank<=1'b1; r_ie<=1'b0;
                end
                if (w_id_issue) begin
                    r_m_valid<=1'b1; r_m_bank<=r_bank;
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
                    r_m_store_data<=w_a;
                    r_m_flags<=w_alu_flags;
                    r_m_next_pc<=w_reti ? r_epc :
                        w_take_branch ? w_branch_pc : w_sequential_pc;
                    case (w_opcode)
                        `CPU8_OP_LDI: r_m_result<=r_id_instruction[7:0];
                        `CPU8_OP_MOV: r_m_result<=w_b;
                        default: r_m_result<=w_alu_result;
                    endcase
                    case (w_opcode)
                        `CPU8_OP_LDXL: r_m_x_data<={w_x[15:8],r_id_instruction[7:0]};
                        `CPU8_OP_LDXH: r_m_x_data<={r_id_instruction[7:0],w_x[7:0]};
                        default: r_m_x_data<=w_x+16'd1;
                    endcase
                    // Interrupt control takes effect when it issues.
                    if (!w_id_fault) begin
                        if (w_ei) r_ie<=1'b1;
                        if (w_di) r_ie<=1'b0;
                        if (w_reti) begin r_ie<=1'b1; r_bank<=1'b0; end
                    end
                    if (w_stop_issue) r_stop_fetch<=1'b1;
                end
                // Refill IF/ID in program order: skid first, then the fetch
                // landing now. A redirect or stop empties both slots.
                if (w_redirect || w_stop_issue) begin
                    r_id_valid<=1'b0; r_sk_valid<=1'b0;
                end else if (w_id_free) begin
                    if (r_sk_valid) begin
                        r_id_valid<=1'b1; r_id_pc<=r_sk_pc;
                        r_id_instruction<=r_sk_instruction; r_id_error<=r_sk_error;
                        r_sk_valid<=w_if_land;
                        if (w_if_land) begin
                            r_sk_pc<=r_if_pc;
                            r_sk_instruction<=i_i_hrdata; r_sk_error<=i_i_hresp;
                        end
                    end else begin
                        r_id_valid<=w_if_land;
                        if (w_if_land) begin
                            r_id_pc<=r_if_pc;
                            r_id_instruction<=i_i_hrdata; r_id_error<=i_i_hresp;
                        end
                    end
                end else if (w_if_land) begin
                    r_sk_valid<=1'b1; r_sk_pc<=r_if_pc;
                    r_sk_instruction<=i_i_hrdata; r_sk_error<=i_i_hresp;
                end
            end
        end
    end
endmodule
`default_nettype wire
