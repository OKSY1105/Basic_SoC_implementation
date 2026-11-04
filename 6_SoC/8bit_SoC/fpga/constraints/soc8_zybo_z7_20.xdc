# ============================================================
# 8bit SoC on Digilent Zybo Z7-20 (xc7z020clg400-1): board top pins.
# Pins and I/O standard from Digilent's Zybo-Z7-Master.xdc; UART on the same
# Pmod JC pins as the UART_LED project (zybo_uart_top.xdc).
#
# Board top ports (the board top built in Vivado must use these names):
#   i_clk125     125 MHz PL clock -> MMCM -> 100 MHz soc8_top i_clk
#   i_btn_rst    BTN0, 1 while pressed -> soc8_top i_rst_n = !i_btn_rst && locked
#   o_uart_txd   soc8_top o_uart_txd -> USB-UART RX (PC) and STM32 USART RX
#   i_uart_rxd   USB-UART TX (PC) -> soc8_top i_uart_rxd
#   o_led[3:0]   suggested: [0] soc8_top o_rst_n (reset released),
#                [1] o_dram_initialized, [2] o_halted, [3] o_fault
# UART: 115200 bps 8E1, 3.3 V. The board USB-UART is on the PS (MIO 48/49),
# so the PL UART needs an external 3.3 V USB-UART adapter on Pmod JC
# (Digilent labels jc_p[1] = V15, jc_n[1] = W15; check the connector pin
# numbers in the Zybo Z7 reference manual before wiring) and a common ground.
# ============================================================

# 125 MHz clock (K17). The MMCM output clock is derived by Vivado. A Clocking
# Wizard IP also defines this clock on its input; Vivado then reports that
# this definition overrides the IP's one (same 8 ns period).
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports i_clk125]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports i_clk125]

# BTN0: reset
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports i_btn_rst]

# UART (Pmod JC): TX = jc_p[1], RX = jc_n[1]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports o_uart_txd]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports i_uart_rxd]

# LEDs LD0..LD3
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {o_led[0]}]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports {o_led[1]}]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports {o_led[2]}]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {o_led[3]}]

# Asynchronous I/O: the button goes through reset_sync (asynchronous assert,
# synchronized release) and the UART RX line through the 2-flip-flop input
# synchronizer of uart_rx; TX and LEDs have no external clock relation.
set_false_path -from [get_ports {i_btn_rst i_uart_rxd}]
set_false_path -to [get_ports {o_uart_txd o_led[*]}]
