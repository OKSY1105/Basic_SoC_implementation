#include <stdint.h>
#include "board.h"
#include "uart_fpga.h"

#define FPGA_BAUDRATE  115200U
#define RXBUF_SIZE     256U                /* power of two */
#define RXBUF_MASK     (RXBUF_SIZE - 1U)

static volatile uint16_t rxbuf[RXBUF_SIZE];
static volatile uint32_t rx_head;          /* written by the interrupt only */
static volatile uint32_t rx_tail;          /* written by uart_fpga_get only */
static volatile uart_fpga_errors_t errs;

void uart_fpga_init(void)
{
    /* GPIOG clock, PG9 = alternate function 8 (USART6_RX).
       Pull-up keeps the line idle (high) while the FPGA wire is off. */
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIOGEN;
    (void)RCC->AHB1ENR;
    GPIOG->MODER  = (GPIOG->MODER  & ~(3U << (9U * 2U))) | (2U << (9U * 2U));
    GPIOG->PUPDR  = (GPIOG->PUPDR  & ~(3U << (9U * 2U))) | (1U << (9U * 2U));
    GPIOG->AFR[1] = (GPIOG->AFR[1] & ~(0xFU << 4U))      | (8U << 4U);

    /* USART6 on APB2 */
    RCC->APB2ENR |= RCC_APB2ENR_USART6EN;
    (void)RCC->APB2ENR;
    USART6->CR1 = 0U;
    USART6->CR2 = 0U;                       /* STOP = 00: 1 stop bit */
    USART6->CR3 = 0U;
    USART6->BRR = (uint16_t)((BOARD_APB2_HZ + (FPGA_BAUDRATE / 2U)) / FPGA_BAUDRATE);

    /* M = 1 with PCE = 1: 8 data bits + parity bit. PS = 0: even parity.
       (M = 0 with PCE = 1 would give 7 data bits + parity.)
       RXNEIE also raises the interrupt on overrun. */
    USART6->CR1 = USART_CR1_M | USART_CR1_PCE | USART_CR1_RE | USART_CR1_RXNEIE;
    USART6->CR1 |= USART_CR1_UE;

    NVIC_SetPriority(USART6_IRQn, 1U);
    NVIC_EnableIRQ(USART6_IRQn);
}

void USART6_IRQHandler(void)
{
    uint32_t sr = USART6->SR;

    if (sr & (USART_SR_RXNE | USART_SR_ORE)) {
        /* Reading SR and then DR clears PE, FE, NF and ORE.
           With M = 1 the parity bit is DR bit 8; keep the 8 data bits. */
        uint16_t entry = (uint16_t)(USART6->DR & 0xFFU);

        if (sr & (USART_SR_PE | USART_SR_FE | USART_SR_NE | USART_SR_ORE)) {
            entry |= UART_FPGA_ERR;
            if (sr & USART_SR_PE)  { errs.parity++;  }
            if (sr & USART_SR_FE)  { errs.framing++; }
            if (sr & USART_SR_NE)  { errs.noise++;   }
            if (sr & USART_SR_ORE) { errs.overrun++; }
        }

        uint32_t next = (rx_head + 1U) & RXBUF_MASK;
        if (next == rx_tail) {
            errs.dropped++;
        } else {
            rxbuf[rx_head] = entry;
            rx_head = next;
        }
    }
}

int uart_fpga_get(uint16_t *entry)
{
    uint32_t tail = rx_tail;

    if (tail == rx_head) {
        return 0;
    }
    *entry = rxbuf[tail];
    rx_tail = (tail + 1U) & RXBUF_MASK;
    return 1;
}

void uart_fpga_get_errors(uart_fpga_errors_t *out)
{
    __disable_irq();
    out->parity  = errs.parity;
    out->framing = errs.framing;
    out->noise   = errs.noise;
    out->overrun = errs.overrun;
    out->dropped = errs.dropped;
    __enable_irq();
}
