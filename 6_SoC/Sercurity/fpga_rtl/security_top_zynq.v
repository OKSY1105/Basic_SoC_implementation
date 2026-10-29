`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: security_top_zynq
// Target Device: CORE-5300 (Xilinx Zynq-7000 XC7Z010CLG400-1)
// Description: Zynq SoC Top-level integrating:
//              1) Zynq PS Block Design Wrapper (zynq_sys_wrapper):
//                 - UART0 on MIO 14, 15 (On-board USB-UART to PC)
//                 - UART1 on EMIO (Internal PL bridge to custom Verilog UART)
//                 - FCLK_CLK0 (50MHz clock to PL)
//                 - DDR and FIXED_IO interfaces for Zynq PS
//              2) Smart Security System (security_top):
//                 - Custom Verilog UART Frame Controller (9600bps, CRC8, 0xAA)
//                 - Ultrasonic Intrusion Detection (HC-SR04) with 5-sample MA
//                 - 24-Hour Digital Clock on 4-Digit 7-Segment
//                 - 4-Step Push Button Password Disarm (PB1 -> PB2 -> PB1 -> PB2)
//                 - Latched Composite Alarm (LED, Buzzer, DRV8848 DC Motor)
//////////////////////////////////////////////////////////////////////////////////

module security_top_zynq (
    // Zynq-7000 Hard Interfaces (Auto-placed on dedicated silicon pads)
    inout  wire [14:0] DDR_0_addr,
    inout  wire [2:0]  DDR_0_ba,
    inout  wire        DDR_0_cas_n,
    inout  wire        DDR_0_ck_n,
    inout  wire        DDR_0_ck_p,
    inout  wire        DDR_0_cke,
    inout  wire        DDR_0_cs_n,
    inout  wire [3:0]  DDR_0_dm,
    inout  wire [31:0] DDR_0_dq,
    inout  wire [3:0]  DDR_0_dqs_n,
    inout  wire [3:0]  DDR_0_dqs_p,
    inout  wire        DDR_0_odt,
    inout  wire        DDR_0_ras_n,
    inout  wire        DDR_0_reset_n,
    inout  wire        DDR_0_we_n,
    inout  wire        FIXED_IO_0_ddr_vrn,
    inout  wire        FIXED_IO_0_ddr_vrp,
    inout  wire [53:0] FIXED_IO_0_mio,
    inout  wire        FIXED_IO_0_ps_clk,
    inout  wire        FIXED_IO_0_ps_porb,
    inout  wire        FIXED_IO_0_ps_srstb,

    // External Physical IO (CORE-5300 Board)
    input  wire [1:0]  pb_key,       // PL Push Buttons: pb_key[0]=PB1(V15), pb_key[1]=PB2(W15)
    input  wire [3:0]  sw,           // Slide Switches SW[3:0] (W14, Y14, T16, U17)
    input  wire [3:0]  touch_key,    // 1x4 Touch Keypad (L15, K16, J16, M17)
    input  wire        sonar_echo,   // HC-SR04 Echo (H20)
    output wire        sonar_trig,   // HC-SR04 Trig (J20)
    output wire [3:0]  fnd_digit,    // 7-Segment Digit[3:0] (U12, T12, T10, T11)
    output wire [7:0]  fnd_seg,      // 7-Segment Seg[7:0] (Y16..V13)
    output wire [3:0]  led,          // PL LEDs (P15, P16, N20, P20)
    output wire        buzzer,       // Buzzer (L19)
    output wire        motor_in1,    // DRV8848 IN1 (K14)
    output wire        motor_in2,    // DRV8848 IN2 / PWM (J14)
    output wire        motor_nsleep, // DRV8848 nSleep (L14)
    output wire        lcd_rs,       // 16x2 Text LCD Register Select (U20)
    output wire        lcd_e,        // 16x2 Text LCD Enable Strobe (V20)
    output wire [7:0]  lcd_data      // 16x2 Text LCD Data DB7..DB0 (W18..W20)
);

    // Internal wires connecting Zynq PS and custom Verilog security_top
    wire fclk_50mhz;
    wire ps_uart1_tx; // Serial TX output from PS (EMIO) -> connects to security_top.uart_rx
    wire ps_uart1_rx; // Serial RX input to PS (EMIO) <- connects from security_top.uart_tx

    // 1. Zynq-7000 Processing System Block Design Wrapper
    zynq_sys_wrapper zynq_sys_i (
        .DDR_0_addr          (DDR_0_addr),
        .DDR_0_ba            (DDR_0_ba),
        .DDR_0_cas_n         (DDR_0_cas_n),
        .DDR_0_ck_n          (DDR_0_ck_n),
        .DDR_0_ck_p          (DDR_0_ck_p),
        .DDR_0_cke           (DDR_0_cke),
        .DDR_0_cs_n          (DDR_0_cs_n),
        .DDR_0_dm            (DDR_0_dm),
        .DDR_0_dq            (DDR_0_dq),
        .DDR_0_dqs_n         (DDR_0_dqs_n),
        .DDR_0_dqs_p         (DDR_0_dqs_p),
        .DDR_0_odt           (DDR_0_odt),
        .DDR_0_ras_n         (DDR_0_ras_n),
        .DDR_0_reset_n       (DDR_0_reset_n),
        .DDR_0_we_n          (DDR_0_we_n),
        .FIXED_IO_0_ddr_vrn  (FIXED_IO_0_ddr_vrn),
        .FIXED_IO_0_ddr_vrp  (FIXED_IO_0_ddr_vrp),
        .FIXED_IO_0_mio      (FIXED_IO_0_mio),
        .FIXED_IO_0_ps_clk   (FIXED_IO_0_ps_clk),
        .FIXED_IO_0_ps_porb  (FIXED_IO_0_ps_porb),
        .FIXED_IO_0_ps_srstb (FIXED_IO_0_ps_srstb),
        .FCLK_CLK0_0         (fclk_50mhz),
        .UART1_RX_0          (ps_uart1_rx),
        .UART1_TX_0          (ps_uart1_tx)
    );

    // 2. Custom Verilog Smart Security System Core
    security_top #(
        .CLKS_PER_US         (50),
        .CLKS_PER_2MS        (100_000),
        .CLKS_PER_50MS       (2_500_000),
        .CLKS_PER_1S         (50_000_000),
        .DEBOUNCE_CYCLES     (1_000_000), // 20ms @ 50MHz
        .SEC_PER_MIN         (6),
        .CLKS_PER_BIT        (5208),      // 50MHz / 9600bps
        .BLINK_TICKS_50MS    (5),
        .REARM_TICKS_50MS    (40),
        .HOLD_RST_TICKS_50MS (40)
    ) u_security_top (
        .clk          (fclk_50mhz),
        .pb_key       (pb_key),
        .sw           (sw),
        .touch_key    (touch_key),
        .sonar_echo   (sonar_echo),
        .sonar_trig   (sonar_trig),
        .fnd_digit    (fnd_digit),
        .fnd_seg      (fnd_seg),
        .led          (led),
        .buzzer       (buzzer),
        .motor_in1    (motor_in1),
        .motor_in2    (motor_in2),
        .motor_nsleep (motor_nsleep),
        .uart_rx      (ps_uart1_tx), // Receive serial stream from PC (via PS bridge)
        .uart_tx      (ps_uart1_rx), // Transmit serial stream to PC (via PS bridge)
        .lcd_rs       (lcd_rs),
        .lcd_e        (lcd_e),
        .lcd_data     (lcd_data)
    );

endmodule
