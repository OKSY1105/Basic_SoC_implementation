`timescale 1ns/1ps
// 8bit SoC program ROM: 4K x 16-bit block ROM with two AHB-Lite slave ports.
//
// Port A (instruction, 16-bit data): CPU instruction port, point-to-point
//   (HSEL tied high, HREADY = o_a_hreadyout at the top level).
//   HADDR is the 17-bit byte address {PC, 1'b0}. A halfword read
//   (HSIZE = 001, HADDR[0] = 0) inside 0x00000-0x01FFF completes with zero
//   wait. Any other transfer (write, other HSIZE, odd HADDR, HADDR >= 0x02000)
//   gets a two-cycle ERROR, which the CPU reports as a fetch fault.
// Port B (data, 8-bit data): CPU data port through the AHB decoder (HSEL for
//   0x0000-0x1FFF). A byte read completes with zero wait. Byte address 2w+k
//   is byte k of word w (little endian: even address = bits [7:0]).
//   Writes and HSIZE != 000 get a two-cycle ERROR with no side effect.
//
// - An address phase is accepted when HSEL && HTRANS[1] && HREADY. The array
//   is read at that clock edge (block-RAM read with enable), so the data is
//   ready in the data phase and stays there until the next accepted read.
// - The two ports read the array independently (dual-port read).
// - HREADYOUT/HRESP depend only on the registered data-phase state. IDLE gets
//   zero-wait OKAY.
// - Contents: MEM_FILE ($readmemh, one 16-bit hex word per line, @address
//   allowed); words not in the file are zero. Reset does not change them.
module soc8_rom #(
    parameter MEM_FILE = ""
) (
    input  wire        i_clk,
    input  wire        i_rstn,
    // Port A: instruction
    input  wire        i_a_hsel,
    input  wire [16:0] i_a_haddr,
    input  wire [1:0]  i_a_htrans,
    input  wire        i_a_hwrite,
    input  wire [2:0]  i_a_hsize,
    input  wire        i_a_hready,
    output wire        o_a_hreadyout,
    output wire        o_a_hresp,                 // 1 = ERROR
    output wire [15:0] o_a_hrdata,
    // Port B: data
    input  wire        i_b_hsel,
    input  wire [15:0] i_b_haddr,
    input  wire [1:0]  i_b_htrans,
    input  wire        i_b_hwrite,
    input  wire [2:0]  i_b_hsize,
    input  wire        i_b_hready,                // bus HREADY
    output wire        o_b_hreadyout,
    output wire        o_b_hresp,                 // 1 = ERROR
    output wire [7:0]  o_b_hrdata
);
    reg [15:0] r_mem [0:4095];
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) r_mem[i] = 16'h0000;
        if (MEM_FILE != "") $readmemh(MEM_FILE, r_mem);
    end

    // Port A
    wire w_a_accept = i_a_hsel && i_a_htrans[1] && i_a_hready;
    wire w_a_ok = !i_a_hwrite && (i_a_hsize == 3'b001) && !i_a_haddr[0] &&
                  (i_a_haddr[16:13] == 4'd0);
    reg [15:0] r_a_data;
    reg r_a_err, r_a_err2;                        // ERROR first / second cycle

    // Port B
    wire w_b_accept = i_b_hsel && i_b_htrans[1] && i_b_hready;
    wire w_b_ok = !i_b_hwrite && (i_b_hsize == 3'b000);
    reg [15:0] r_b_word;
    reg r_b_high;                                 // odd byte address
    reg r_b_err, r_b_err2;

    // Block-RAM reads (no reset, so the tools can map them to BRAM).
    always @(posedge i_clk) begin
        if (w_a_accept && w_a_ok) r_a_data <= r_mem[i_a_haddr[12:1]];
        if (w_b_accept && w_b_ok) begin
            r_b_word <= r_mem[i_b_haddr[12:1]]; r_b_high <= i_b_haddr[0];
        end
    end

    // Data-phase state: updated only while the port's HREADY is high.
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_a_err <= 1'b0; r_a_err2 <= 1'b0;
            r_b_err <= 1'b0; r_b_err2 <= 1'b0;
        end else begin
            if (i_a_hready) begin
                r_a_err <= w_a_accept && !w_a_ok; r_a_err2 <= 1'b0;
            end else if (r_a_err) begin
                r_a_err2 <= 1'b1;
            end
            if (i_b_hready) begin
                r_b_err <= w_b_accept && !w_b_ok; r_b_err2 <= 1'b0;
            end else if (r_b_err) begin
                r_b_err2 <= 1'b1;
            end
        end
    end

    assign o_a_hreadyout = r_a_err ? r_a_err2 : 1'b1;
    assign o_a_hresp = r_a_err;
    assign o_a_hrdata = r_a_data;
    assign o_b_hreadyout = r_b_err ? r_b_err2 : 1'b1;
    assign o_b_hresp = r_b_err;
    assign o_b_hrdata = r_b_high ? r_b_word[15:8] : r_b_word[7:0];
endmodule
