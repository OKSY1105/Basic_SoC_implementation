`timescale 1ns/1ps
`default_nettype none
// 8bit SoC board top for Digilent Zybo Z7-20 (xc7z020clg400-1), PL only.
//   Clock: i_clk125 (K17, 125 MHz) -> MMCME2_BASE -> BUFG -> 100 MHz for
//     soc8_top and the BRAM-based DRAM model (one clock, as the model needs:
//     CK = i_clk / 4 from the same i_clk). VCO = 125 x 8 = 1000 MHz
//     (600..1200 MHz for speed grade -1), output = VCO / 10.
//   Reset: soc8_top i_rst_n = !i_btn_rst && MMCM locked. soc8_top's
//     reset_sync asserts at once and releases on the 100 MHz clock.
//   DRAM: dram_bram_model on the DRAM controller core's split pins inside
//     the FPGA (no tri-state, no FPGA pins); the output enables are unused.
//   UART: 115200 bps 8E1 on Pmod JC (external 3.3 V USB-UART; the board's
//     USB-UART is on the PS).
//   LEDs: [0] reset released (soc8_top o_rst_n), [1] DRAM initialized,
//     [2] CPU halted, [3] CPU fault. The other debug outputs are unused.
// Pins: fpga/constraints/soc8_zybo_z7_20.xdc. ROM_FILE: the assembled
// calculator firmware (firmware/calc.asm -> calc.mem); scripts/build_zybo.sh
// passes its absolute path to synthesis.
module soc8_zybo_top #(
    parameter ROM_FILE = "",                      // $readmemh image, 16-bit words
    parameter integer BAUD_RATE = 115200
) (
    input  wire       i_clk125,
    input  wire       i_btn_rst,                  // BTN0, 1 while pressed
    input  wire       i_uart_rxd,
    output wire       o_uart_txd,
    output wire [3:0] o_led
);
    // ------------------------------------------------------------- clock
    wire w_clkfb_mmcm, w_clkfb, w_clk100_mmcm, w_clk100, w_locked;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(8.000),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(8.000),
        .CLKFBOUT_PHASE(0.000),
        .CLKOUT0_DIVIDE_F(10.000),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKIN1(i_clk125),
        .CLKFBIN(w_clkfb),
        .CLKFBOUT(w_clkfb_mmcm),
        .CLKFBOUTB(),
        .CLKOUT0(w_clk100_mmcm),
        .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(),
        .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
        .LOCKED(w_locked),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );
    BUFG u_bufg_fb  (.I(w_clkfb_mmcm),  .O(w_clkfb));
    BUFG u_bufg_clk (.I(w_clk100_mmcm), .O(w_clk100));

    // ------------------------------------------------------------- reset
    wire w_rst_n = !i_btn_rst && w_locked;      // asynchronous, active low

    // ------------------------------------------------------------- SoC
    wire        w_ck_t, w_ck_c, w_cke, w_csn, w_actn, w_dq_oe, w_dqs_t, w_dqs_c, w_dqs_oe;
    wire [1:0]  w_bg, w_ba;
    wire [17:0] w_a;
    wire [7:0]  w_dq_o, w_dq_i;
    wire        w_model_dq_oe;
    wire        w_rst_sync, w_halted, w_fault, w_dram_init;

    soc8_top #(
        .ROM_FILE(ROM_FILE),
        .CLK_FREQ_HZ(100_000_000),
        .BAUD_RATE(BAUD_RATE)
    ) u_soc (
        .i_clk(w_clk100), .i_rst_n(w_rst_n),
        .i_uart_rxd(i_uart_rxd), .o_uart_txd(o_uart_txd),
        .o_dram_ck_t(w_ck_t), .o_dram_ck_c(w_ck_c), .o_dram_cke(w_cke),
        .o_dram_csn(w_csn), .o_dram_actn(w_actn), .o_dram_bg(w_bg), .o_dram_ba(w_ba),
        .o_dram_a(w_a), .o_dram_dq(w_dq_o), .o_dram_dq_oe(w_dq_oe), .i_dram_dq(w_dq_i),
        .o_dram_dqs_t(w_dqs_t), .o_dram_dqs_c(w_dqs_c), .o_dram_dqs_oe(w_dqs_oe),
        .o_rst_n(w_rst_sync), .o_halted(w_halted), .o_fault(w_fault), .o_fault_code(),
        .o_pc(), .o_irq(), .o_irq_active(), .o_dram_initialized(w_dram_init),
        .o_cache_access_count(), .o_cache_miss_count(), .o_cache_writeback_count(),
        .o_bus_err_addr(), .o_bus_err_count()
    );

    // ------------------------------------------------------------- DRAM
    dram_bram_model u_dram (
        .i_clk(w_clk100), .i_ck_t(w_ck_t), .i_ck_c(w_ck_c), .i_cke(w_cke),
        .i_csn(w_csn), .i_actn(w_actn), .i_bg(w_bg), .i_ba(w_ba), .i_a(w_a),
        .i_dq(w_dq_o), .o_dq(w_dq_i), .o_dq_oe(w_model_dq_oe),
        .i_dqs_t(w_dqs_t), .i_dqs_c(w_dqs_c)
    );

    // ------------------------------------------------------------- LEDs
    assign o_led = {w_fault, w_halted, w_dram_init, w_rst_sync};
endmodule
`default_nettype wire
