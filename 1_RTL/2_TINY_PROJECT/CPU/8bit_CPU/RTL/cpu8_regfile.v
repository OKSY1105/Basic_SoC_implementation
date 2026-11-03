`timescale 1ns/1ps
`default_nettype none
// Reference: CPU/DU/irf.v. Four 8-bit 2R1W registers; R0 is writable.
// Two banks: bank 0 for the program, bank 1 for the interrupt handler.
// Reads use i_rbank (the bank in use), the write uses i_wbank (the bank of
// the completing instruction).
// No combinational WB forwarding. The pipeline interlock waits for commit.
module cpu8_regfile (
    input wire i_clk, i_rst_n,
    input wire [1:0] i_ra, i_rb, i_wa,
    input wire i_rbank, i_wbank,
    input wire [7:0] i_wdata,
    input wire i_we,
    output wire [7:0] o_a, o_b,
    output wire [31:0] o_registers,     // bank 0
    output wire [31:0] o_registers_irq  // bank 1
);
    reg [7:0] r_regs [0:7];             // {bank, register}
    integer k;
    always @(posedge i_clk) begin
        if (!i_rst_n)
            for (k=0;k<8;k=k+1) r_regs[k]<=8'b0;
        else if (i_we) r_regs[{i_wbank,i_wa}]<=i_wdata;
    end
    assign o_a=r_regs[{i_rbank,i_ra}];
    assign o_b=r_regs[{i_rbank,i_rb}];
    assign o_registers={r_regs[3],r_regs[2],r_regs[1],r_regs[0]};
    assign o_registers_irq={r_regs[7],r_regs[6],r_regs[5],r_regs[4]};
endmodule
`default_nettype wire
