##################################################################################
## Target Board : CORE-5300 (Xilinx Zynq-7000 XC7Z010CLG400-1)
## Reference    : CORE-5300_PIN.pdf & SoC설계실습장비_CORE-5300.pdf
## Hardware SW  : 1) Camera vs Sensor/Motor switch -> Set to SENSOR/MOTOR
##                2) DC Motor vs Step Motor switch -> Set to DC MOTOR
##################################################################################

## 1. PL System Clock (50MHz)
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} -add [get_ports clk]

## 2. PL Push Buttons PB1 (V15) & PB2 (W15) -> 4-Step Sequential Password (PB1 -> PB2 -> PB1 -> PB2)
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {pb_key[0]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports {pb_key[1]}]

## 3. PL Slide Switches SW[3:0] -> Dynamic Threshold Distance (10 + SW*5 cm)
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]

## 4. 1x4 Capacitive Touch Keypad (TTP224) -> Sequential Password Disarm (1 -> 2 -> 3 -> 4)
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33} [get_ports {touch_key[0]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {touch_key[1]}]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {touch_key[2]}]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {touch_key[3]}]

## 5. Ultrasonic Sensor (HC-SR04)
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS33} [get_ports sonar_trig]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD LVCMOS33} [get_ports sonar_echo]

## 6. 4-Digit 7-Segment Display
##    - Digit[3:0]: Active High (1 = ON)
##    - Seg[7:0] (dp, g, f, e, d, c, b, a): Common Anode / Active Low (0 = ON)
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {fnd_digit[0]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {fnd_digit[1]}]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports {fnd_digit[2]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {fnd_digit[3]}]

set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[0]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[1]}]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[2]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[3]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[4]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[5]}]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[6]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {fnd_seg[7]}]

## 7. PL Alarm LEDs (LED 0~3, Active High)
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## 8. Alarm Buzzer (Active High)
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports buzzer]

## 9. DC Motor Driver (DRV8848)
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} [get_ports motor_in1]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports motor_in2]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports motor_nsleep]

## 10. UART TX / RX
## [NOTE on CORE-5300 On-Board USB-UART Cable (MIO 14, 15)]:
## - When connecting via the on-board USB-UART connector (Zynq PS MIO 14/15),
##   connect `uart_rx` and `uart_tx` internally to the Zynq7 Processing System block
##   (UART1 EMIO or AXI UART bridge) and comment out the two external GPIO lines below.
## - When synthesized standalone as pure PL top, `uart_rx`/`uart_tx` are mapped to
##   spare PL header pins (G15 / G14) with internal PULLUP on `uart_rx` so that
##   even when no external UART cable is plugged in, `uart_rx` stays Idle High (1).
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports uart_tx]

## 11. 16x2 Character Text LCD (S6A0069 / HD44780)
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports lcd_rs]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports lcd_e]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports {lcd_data[0]}]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {lcd_data[1]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {lcd_data[2]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {lcd_data[3]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {lcd_data[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {lcd_data[5]}]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {lcd_data[6]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {lcd_data[7]}]

