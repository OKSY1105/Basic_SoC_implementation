#include <stdint.h>
#include "board.h"
#include "uart_dbg.h"

#define DBG_BAUDRATE  115200U

int __io_putchar(int ch)
{
    uart_dbg_write(ch);
    return ch;
}

/* newlib calls _write() for printf(); every stream goes to USART3. */
int _write(int file, char *buf, int len)
{
    (void)file;
    for (int i = 0; i < len; i++) {
        uart_dbg_write((unsigned char)buf[i]);
    }
    return len;
}

void uart_dbg_init(void)
{
    /* GPIOD clock, PD8 = alternate function 7 (USART3_TX) */
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIODEN;
    (void)RCC->AHB1ENR;
    GPIOD->MODER  = (GPIOD->MODER  & ~(3U << (8U * 2U))) | (2U << (8U * 2U));
    GPIOD->AFR[1] = (GPIOD->AFR[1] & ~(0xFU << 0U))      | (7U << 0U);

    /* USART3 on APB1: 8N1, TX only */
    RCC->APB1ENR |= RCC_APB1ENR_USART3EN;
    (void)RCC->APB1ENR;
    USART3->CR1 = 0U;
    USART3->CR2 = 0U;
    USART3->CR3 = 0U;
    USART3->BRR = (uint16_t)((BOARD_APB1_HZ + (DBG_BAUDRATE / 2U)) / DBG_BAUDRATE);
    USART3->CR1 = USART_CR1_TE;
    USART3->CR1 |= USART_CR1_UE;
}

void uart_dbg_write(int ch)
{
    while (!(USART3->SR & USART_SR_TXE)) {
    }
    USART3->DR = (uint32_t)ch & 0xFFU;
}
