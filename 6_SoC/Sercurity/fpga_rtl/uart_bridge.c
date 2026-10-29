/******************************************************************************
* File: uart_bridge.c
* Target: CORE-5300 (Xilinx Zynq-7000 XC7Z010CLG400-1)
* Description:
*   Zero-overhead, pure register-level UART Pass-Through Bridge:
*   - UART0: 0xE0000000 (MIO 14, 15 -> On-board Mini-USB to PC)
*   - UART1: 0xE0001000 (EMIO -> Custom Verilog Smart Security Core)
*   - Explicitly configures BOTH UARTs to 9600 bps (8N1)
*   - Enables PS-PL Level Shifters & releases FPGA resets
******************************************************************************/

#define UART0_BASE 0xE0000000U
#define UART1_BASE 0xE0001000U

#define UART_CR(base)      (*(volatile unsigned int *)((base) + 0x00U))
#define UART_MR(base)      (*(volatile unsigned int *)((base) + 0x04U))
#define UART_BAUDGEN(base) (*(volatile unsigned int *)((base) + 0x18U))
#define UART_SR(base)      (*(volatile unsigned int *)((base) + 0x2CU))
#define UART_FIFO(base)    (*(volatile unsigned int *)((base) + 0x30U))
#define UART_BAUDDIV(base) (*(volatile unsigned int *)((base) + 0x34U))

#define SLCR_UNLOCK        (*(volatile unsigned int *)(0xF8000008U))
#define SLCR_LOCK          (*(volatile unsigned int *)(0xF8000004U))
#define SLCR_LVL_SHFTR_EN  (*(volatile unsigned int *)(0xF8000900U))
#define SLCR_FPGA_RST_CTRL (*(volatile unsigned int *)(0xF8000240U))

#define RXEMPTY_MASK 0x00000002U
#define TXFULL_MASK  0x00000010U

static void init_uart_9600(unsigned int base) {
    // 1. Disable TX and RX while configuring
    UART_CR(base) = 0x00000028U; // TXDIS (0x20) | RXDIS (0x08)

    // 2. Set 9600 baud for 100MHz clock:
    //    Baud = 100MHz / (1488 * (6 + 1)) = 100,000,000 / 10416 = 9600.61 bps
    UART_BAUDGEN(base) = 1488U;
    UART_BAUDDIV(base) = 6U;

    // 3. Mode: Normal mode, 1 stop bit, no parity, 8 data bits, sel_clk=uart_ref_clk
    UART_MR(base) = 0x00000020U;

    // 4. Reset FIFOs and Enable TX & RX
    UART_CR(base) = 0x00000017U; // TXEN(0x10) | RXEN(0x04) | TXRES(0x02) | RXRES(0x01)
}

int main(void) {
    unsigned int b;

    // 1. Disable all interrupts (pure polling loop, prevent unhandled IRQ traps)
    __asm__ volatile ("cpsid if");

    // 2. Unlock SLCR, ensure PS-PL level shifters are active and PL resets are released
    SLCR_UNLOCK = 0x0000DF0DU;
    SLCR_LVL_SHFTR_EN = 0x0000000FU;
    SLCR_FPGA_RST_CTRL = 0x00000000U;
    SLCR_LOCK = 0x0000767BU;

    // 3. Initialize UART0 (PC MIO) and UART1 (PL EMIO) to 9600 bps
    init_uart_9600(UART0_BASE);
    init_uart_9600(UART1_BASE);

    // 4. Continuous ultra-fast non-blocking forwarding loop
    while (1) {
        // Forward from PC (UART0) -> Verilog Security RTL (UART1)
        if ((UART_SR(UART0_BASE) & RXEMPTY_MASK) == 0U) {
            b = UART_FIFO(UART0_BASE);
            while ((UART_SR(UART1_BASE) & TXFULL_MASK) != 0U);
            UART_FIFO(UART1_BASE) = b;
        }

        // Forward from Verilog Security RTL (UART1) -> PC (UART0)
        if ((UART_SR(UART1_BASE) & RXEMPTY_MASK) == 0U) {
            b = UART_FIFO(UART1_BASE);
            while ((UART_SR(UART0_BASE) & TXFULL_MASK) != 0U);
            UART_FIFO(UART0_BASE) = b;
        }
    }

    return 0;
}
