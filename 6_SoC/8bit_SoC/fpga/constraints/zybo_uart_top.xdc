# ============================================================
# Zybo Z7-10 / Z7-20
# ============================================================

# 125 MHz Clock
set_property PACKAGE_PIN K17 [get_ports i_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_clk]
create_clock -add -name sys_clk_pin \
    -period 8.000 \
    -waveform {0 4} \
    [get_ports i_clk]


# BTN0 : SEND
set_property PACKAGE_PIN K18 [get_ports i_btn_send]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_send]


# BTN1 : RESET
set_property PACKAGE_PIN P16 [get_ports i_btn_reset]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_reset]


# LED0
set_property PACKAGE_PIN M14 [get_ports {o_led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[0]}]


# LED1
set_property PACKAGE_PIN M15 [get_ports {o_led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[1]}]


# LED2
set_property PACKAGE_PIN G14 [get_ports {o_led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[2]}]


# LED3
set_property PACKAGE_PIN D18 [get_ports {o_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[3]}]


# UART TX
set_property PACKAGE_PIN V15 [get_ports o_uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_txd]


# UART RX
set_property PACKAGE_PIN W15 [get_ports i_uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rxd]