`timescale 1ns/1ps
`default_nettype none
// 8bit SoC top: CPU, program ROM, AHB-Lite data bus, data cache + DRAM
// controller, AHB-to-APB3 bridge and UART, behind one reset synchronizer.
// Board pins, the MMCM and the memory behind the DRAM pins are outside.
//
//   CPU instruction port ── ROM port A (point to point, 16-bit data)
//   CPU data port ── soc8_ahb_bus ─┬ 0x0000-0x1FFF  ROM port B (read only)
//                                  ├ 0x8000-0x87FF  cache ── DRAM controller core ── DRAM pins
//                                  ├ 0xF000-0xFFFF  AHB-to-APB3 bridge ── UART (0xFF00-0xFF04)
//                                  └ other          default slave (ERROR)
//   UART o_irq ── CPU i_irq (level; handler vector word 0x0002)
//
// - Clock: one clock i_clk. On the board it is 100 MHz from an MMCM on the
//   125 MHz PL input (board top). PCLK = HCLK. The DRAM controller makes the
//   memory clock CK = i_clk / 4.
// - Reset: i_rst_n is asynchronous, active low (board: button AND MMCM
//   locked). reset_sync gives o_rst_n (asynchronous assert, release on the
//   second rising edge); the CPU and the DRAM controller take it
//   synchronously, the other modules asynchronously.
// - DRAM pins: the controller core's split DQ/DQS (output, output enable,
//   input; no tri-state). Simulation connects sim/models/soc8_dram_model.v
//   (tri-state + behavioral dram.v); the board connects the BRAM-based model.
//   The cache sends 64-bit line requests; line number = RAM byte address
//   [10:3] = controller address {row, column}.
// - Debug outputs (for the TB and the board ILA): CPU halt/fault/PC, IRQ,
//   DRAM initialized, cache counters, default-slave error address/count.
// Specs: 02_design/bus.md (address map, bus rules), interfaces.md,
// uart.md (registers), ram.md, calculator.md (UART use).
module soc8_top #(
    parameter ROM_FILE    = "",                   // $readmemh image, 16-bit words
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115200,
    parameter integer DRAM_T_RCD = 9,
    parameter integer DRAM_CL    = 9,
    parameter integer DRAM_CWL   = 10
) (
    input  wire        i_clk,
    input  wire        i_rst_n,                   // asynchronous, active low
    // UART (8E1)
    input  wire        i_uart_rxd,
    output wire        o_uart_txd,
    // DRAM pins (controller core)
    output wire        o_dram_ck_t,
    output wire        o_dram_ck_c,
    output wire        o_dram_cke,
    output wire        o_dram_csn,
    output wire        o_dram_actn,
    output wire [1:0]  o_dram_bg,
    output wire [1:0]  o_dram_ba,
    output wire [17:0] o_dram_a,
    output wire [7:0]  o_dram_dq,
    output wire        o_dram_dq_oe,
    input  wire [7:0]  i_dram_dq,
    output wire        o_dram_dqs_t,
    output wire        o_dram_dqs_c,
    output wire        o_dram_dqs_oe,
    // Debug
    output wire        o_rst_n,                   // synchronized reset
    output wire        o_halted,
    output wire        o_fault,
    output wire [2:0]  o_fault_code,
    output wire [15:0] o_pc,
    output wire        o_irq,
    output wire        o_irq_active,
    output wire        o_dram_initialized,
    output wire [15:0] o_cache_access_count,
    output wire [15:0] o_cache_miss_count,
    output wire [15:0] o_cache_writeback_count,
    output wire [15:0] o_bus_err_addr,
    output wire [15:0] o_bus_err_count
);
    wire w_rst_n;

    // CPU instruction port (point to point to ROM port A)
    wire [16:0] w_i_haddr;
    wire [1:0]  w_i_htrans;
    wire [2:0]  w_i_hsize;
    wire        w_i_hwrite;
    wire [15:0] w_i_hrdata;
    wire        w_i_hready, w_i_hresp;

    // CPU data port (AHB-Lite bus)
    wire [15:0] w_d_haddr;
    wire [1:0]  w_d_htrans;
    wire [2:0]  w_d_hsize;
    wire        w_d_hwrite;
    wire [7:0]  w_d_hwdata, w_d_hrdata;
    wire        w_d_hready, w_d_hresp;
    wire        w_hsel_rom, w_hsel_ram, w_hsel_apb;
    wire [7:0]  w_rom_hrdata, w_ram_hrdata, w_apb_hrdata;
    wire        w_rom_hreadyout, w_ram_hreadyout, w_apb_hreadyout;
    wire        w_rom_hresp, w_ram_hresp, w_apb_hresp;

    // Cache line port
    wire        w_mem_req, w_mem_write, w_mem_ack;
    wire [7:0]  w_mem_address;
    wire [63:0] w_mem_wdata, w_mem_rdata;

    // APB3
    wire        w_psel, w_penable, w_pwrite, w_pready, w_pslverr;
    wire [11:0] w_paddr;
    wire [7:0]  w_pwdata, w_prdata;

    wire        w_irq;

    assign o_rst_n = w_rst_n;
    assign o_irq   = w_irq;

    reset_sync #(.STAGES(2)) u_reset_sync (
        .i_clk(i_clk), .i_rst_n(i_rst_n), .o_rst_n(w_rst_n));

    cpu8_top u_cpu (
        .i_clk(i_clk), .i_rst_n(w_rst_n),
        .o_i_haddr(w_i_haddr), .o_i_htrans(w_i_htrans), .o_i_hsize(w_i_hsize),
        .o_i_hburst(), .o_i_hprot(), .o_i_hwrite(w_i_hwrite), .o_i_hmastlock(),
        .i_i_hrdata(w_i_hrdata), .i_i_hready(w_i_hready), .i_i_hresp(w_i_hresp),
        .o_d_haddr(w_d_haddr), .o_d_htrans(w_d_htrans), .o_d_hsize(w_d_hsize),
        .o_d_hburst(), .o_d_hprot(), .o_d_hwrite(w_d_hwrite), .o_d_hmastlock(),
        .o_d_hwdata(w_d_hwdata), .i_d_hrdata(w_d_hrdata),
        .i_d_hready(w_d_hready), .i_d_hresp(w_d_hresp),
        .i_irq(w_irq),
        .o_halted(o_halted), .o_fault(o_fault), .o_fault_code(o_fault_code), .o_pc(o_pc),
        .o_x(), .o_flags(), .o_registers(), .o_stall(), .o_stage_valid(),
        .o_retire_valid(), .o_retire_pc(), .o_retire_instruction(),
        .o_retire_reg_write(), .o_retire_rd(), .o_retire_data(), .o_retire_bank(),
        .o_irq_active(o_irq_active));

    // Port A: HSEL tied high, HREADY = its own HREADYOUT (registered only).
    soc8_rom #(.MEM_FILE(ROM_FILE)) u_rom (
        .i_clk(i_clk), .i_rstn(w_rst_n),
        .i_a_hsel(1'b1), .i_a_haddr(w_i_haddr), .i_a_htrans(w_i_htrans),
        .i_a_hwrite(w_i_hwrite), .i_a_hsize(w_i_hsize), .i_a_hready(w_i_hready),
        .o_a_hreadyout(w_i_hready), .o_a_hresp(w_i_hresp), .o_a_hrdata(w_i_hrdata),
        .i_b_hsel(w_hsel_rom), .i_b_haddr(w_d_haddr), .i_b_htrans(w_d_htrans),
        .i_b_hwrite(w_d_hwrite), .i_b_hsize(w_d_hsize), .i_b_hready(w_d_hready),
        .o_b_hreadyout(w_rom_hreadyout), .o_b_hresp(w_rom_hresp), .o_b_hrdata(w_rom_hrdata));

    soc8_ahb_bus u_bus (
        .i_clk(i_clk), .i_rstn(w_rst_n),
        .i_haddr(w_d_haddr), .i_htrans(w_d_htrans),
        .o_hrdata(w_d_hrdata), .o_hready(w_d_hready), .o_hresp(w_d_hresp),
        .o_hsel_rom(w_hsel_rom), .o_hsel_ram(w_hsel_ram), .o_hsel_apb(w_hsel_apb),
        .i_hrdata_rom(w_rom_hrdata), .i_hreadyout_rom(w_rom_hreadyout), .i_hresp_rom(w_rom_hresp),
        .i_hrdata_ram(w_ram_hrdata), .i_hreadyout_ram(w_ram_hreadyout), .i_hresp_ram(w_ram_hresp),
        .i_hrdata_apb(w_apb_hrdata), .i_hreadyout_apb(w_apb_hreadyout), .i_hresp_apb(w_apb_hresp),
        .o_err_addr(o_bus_err_addr), .o_err_count(o_bus_err_count));

    cache u_cache (
        .i_clk(i_clk), .i_rstn(w_rst_n),
        .i_hsel(w_hsel_ram), .i_haddr(w_d_haddr), .i_htrans(w_d_htrans),
        .i_hwrite(w_d_hwrite), .i_hsize(w_d_hsize), .i_hwdata(w_d_hwdata),
        .i_hready(w_d_hready),
        .o_hreadyout(w_ram_hreadyout), .o_hresp(w_ram_hresp), .o_hrdata(w_ram_hrdata),
        .o_mem_req(w_mem_req), .o_mem_write(w_mem_write), .o_mem_address(w_mem_address),
        .o_mem_wdata(w_mem_wdata), .i_mem_ack(w_mem_ack), .i_mem_rdata(w_mem_rdata),
        .o_access_count(o_cache_access_count), .o_miss_count(o_cache_miss_count),
        .o_writeback_count(o_cache_writeback_count));

    // Line requests only: the byte port of the controller is not used.
    dram_controller_core #(
        .T_RCD_CYCLES(DRAM_T_RCD), .CL_CYCLES(DRAM_CL), .CWL_CYCLES(DRAM_CWL)
    ) u_dram_ctrl (
        .i_clk(i_clk), .i_rst_n(w_rst_n),
        .i_req(w_mem_req), .i_write(w_mem_write), .i_line(1'b1),
        .i_addr({w_mem_address, 3'b000}), .i_wdata(8'h00), .i_line_wdata(w_mem_wdata),
        .o_ready(w_mem_ack), .o_rdata(), .o_line_rdata(w_mem_rdata),
        .o_error(), .o_busy(), .o_initialized(o_dram_initialized),
        .o_dram_ck_t(o_dram_ck_t), .o_dram_ck_c(o_dram_ck_c), .o_dram_cke(o_dram_cke),
        .o_dram_csn(o_dram_csn), .o_dram_actn(o_dram_actn), .o_dram_bg(o_dram_bg),
        .o_dram_ba(o_dram_ba), .o_dram_a(o_dram_a),
        .o_dram_dq(o_dram_dq), .o_dram_dq_oe(o_dram_dq_oe), .i_dram_dq(i_dram_dq),
        .o_dram_dqs_t(o_dram_dqs_t), .o_dram_dqs_c(o_dram_dqs_c), .o_dram_dqs_oe(o_dram_dqs_oe));

    ahb_apb_bridge #(.HADDR_W(16), .PADDR_W(12), .DATA_W(8)) u_apb_bridge (
        .i_clk(i_clk), .i_rstn(w_rst_n),
        .i_hsel(w_hsel_apb), .i_haddr(w_d_haddr), .i_htrans(w_d_htrans),
        .i_hwrite(w_d_hwrite), .i_hsize(w_d_hsize), .i_hwdata(w_d_hwdata),
        .i_hready(w_d_hready),
        .o_hreadyout(w_apb_hreadyout), .o_hresp(w_apb_hresp), .o_hrdata(w_apb_hrdata),
        .o_psel(w_psel), .o_penable(w_penable), .o_paddr(w_paddr), .o_pwrite(w_pwrite),
        .o_pwdata(w_pwdata), .i_prdata(w_prdata), .i_pready(w_pready), .i_pslverr(w_pslverr));

    // The only APB slave: PSEL drives it directly.
    soc8_uart_apb #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .i_clk(i_clk), .i_rstn(w_rst_n),
        .i_psel(w_psel), .i_penable(w_penable), .i_paddr(w_paddr), .i_pwrite(w_pwrite),
        .i_pwdata(w_pwdata), .o_prdata(w_prdata), .o_pready(w_pready), .o_pslverr(w_pslverr),
        .o_irq(w_irq), .o_uart_txd(o_uart_txd), .i_uart_rxd(i_uart_rxd));
endmodule
`default_nettype wire
