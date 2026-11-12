#ifndef UART_FPGA_H
#define UART_FPGA_H

#include <stdint.h>

/*
 * FPGA reply input: USART6 RX on PG9 (AF8, Arduino D0 on the NUCLEO-F439ZI),
 * 115200 bps, 8 data bits, even parity, 1 stop bit (8E1) like the FPGA UART.
 * Receive only; the STM32 never sends to the FPGA.
 *
 * Bytes are taken in the USART6 interrupt and kept in a ring buffer.
 * Each entry is the data byte, plus UART_FPGA_ERR when the byte came with a
 * parity, framing, noise or overrun error. An entry with UART_FPGA_LOST (no
 * data byte) marks the place where received bytes were dropped because the
 * buffer was full; the reader must treat that line as damaged.
 */
#define UART_FPGA_ERR   0x100U
#define UART_FPGA_LOST  0x200U

typedef struct {
    uint32_t parity;    /* PE */
    uint32_t framing;   /* FE */
    uint32_t noise;     /* NF */
    uint32_t overrun;   /* ORE */
    uint32_t dropped;   /* ring buffer full */
} uart_fpga_errors_t;

void uart_fpga_init(void);
int  uart_fpga_get(uint16_t *entry);          /* 1 = got an entry, 0 = empty */
void uart_fpga_get_errors(uart_fpga_errors_t *out);

#endif
