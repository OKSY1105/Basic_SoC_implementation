`timescale 1ns/1ps
// AHB-Lite interconnect for the 8bit SoC data port (single master, 8-bit
// data): address decoder, response multiplexer and default slave.
//
//   HADDR          slave                         HSEL
//   0x0000-0x1FFF  ROM port B (read only)        o_hsel_rom
//   0x8000-0x87FF  RAM (data cache)              o_hsel_ram
//   0xF000-0xFFFF  AHB-to-APB3 bridge (UART)     o_hsel_apb
//   other          default slave (internal)      -
//
// - HSEL is decoded from HADDR in the address phase. Exactly one slave
//   (including the default slave) is selected at any time.
// - The select is registered while HREADY is high, so the data phase takes
//   HRDATA/HREADYOUT/HRESP from the slave that owns it; the outputs of the
//   other slaves are ignored. After reset the default slave owns the data
//   phase (HREADY high, OKAY).
// - o_hready is the bus HREADY: it goes back to the master and to every
//   slave. HADDR/HTRANS/HWRITE/HSIZE/HWDATA go from the master to the
//   slaves directly and are not routed here.
// - Default slave: a NONSEQ transfer gets a two-cycle ERROR, IDLE gets
//   zero-wait OKAY. The last unmapped address and the number of such
//   transfers are kept for debug (ILA).
module soc8_ahb_bus (
    input  wire        i_clk,
    input  wire        i_rstn,
    // Master (CPU data port)
    input  wire [15:0] i_haddr,
    input  wire [1:0]  i_htrans,
    output reg  [7:0]  o_hrdata,
    output reg         o_hready,
    output reg         o_hresp,                   // 1 = ERROR
    // Slave selects
    output wire        o_hsel_rom,
    output wire        o_hsel_ram,
    output wire        o_hsel_apb,
    // Slave responses
    input  wire [7:0]  i_hrdata_rom,
    input  wire        i_hreadyout_rom,
    input  wire        i_hresp_rom,
    input  wire [7:0]  i_hrdata_ram,
    input  wire        i_hreadyout_ram,
    input  wire        i_hresp_ram,
    input  wire [7:0]  i_hrdata_apb,
    input  wire        i_hreadyout_apb,
    input  wire        i_hresp_apb,
    // Debug (default slave)
    output reg  [15:0] o_err_addr,                // last unmapped address
    output reg  [15:0] o_err_count                // unmapped transfers
);
    localparam [1:0] S_DEF = 2'd0, S_ROM = 2'd1, S_RAM = 2'd2, S_APB = 2'd3;

    assign o_hsel_rom = (i_haddr[15:13] == 3'b000);
    assign o_hsel_ram = (i_haddr[15:11] == 5'b10000);
    assign o_hsel_apb = (i_haddr[15:12] == 4'hF);
    wire w_hsel_def = !o_hsel_rom && !o_hsel_ram && !o_hsel_apb;

    reg [1:0] r_sel;                              // slave owning the data phase
    reg r_err, r_err2;                            // default slave ERROR cycles
    wire w_def_accept = w_hsel_def && i_htrans[1] && o_hready;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_sel <= S_DEF; r_err <= 1'b0; r_err2 <= 1'b0;
            o_err_addr <= 16'd0; o_err_count <= 16'd0;
        end else if (o_hready) begin
            r_sel <= o_hsel_rom ? S_ROM : o_hsel_ram ? S_RAM :
                     o_hsel_apb ? S_APB : S_DEF;
            r_err <= w_def_accept; r_err2 <= 1'b0;
            if (w_def_accept) begin
                o_err_addr <= i_haddr; o_err_count <= o_err_count + 16'd1;
            end
        end else if (r_err) begin
            r_err2 <= 1'b1;
        end
    end

    always @* begin
        case (r_sel)
            S_ROM: begin
                o_hrdata = i_hrdata_rom; o_hready = i_hreadyout_rom; o_hresp = i_hresp_rom;
            end
            S_RAM: begin
                o_hrdata = i_hrdata_ram; o_hready = i_hreadyout_ram; o_hresp = i_hresp_ram;
            end
            S_APB: begin
                o_hrdata = i_hrdata_apb; o_hready = i_hreadyout_apb; o_hresp = i_hresp_apb;
            end
            default: begin
                o_hrdata = 8'h00; o_hready = r_err ? r_err2 : 1'b1; o_hresp = r_err;
            end
        endcase
    end
endmodule
