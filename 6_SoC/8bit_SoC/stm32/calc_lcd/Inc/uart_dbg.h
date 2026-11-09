#ifndef UART_DBG_H
#define UART_DBG_H

/*
 * Debug output: USART3 TX on PD8 (AF7), 115200 8N1, TX only.
 * On the NUCLEO-F439ZI, USART3 PD8/PD9 is wired to the ST-LINK virtual COM
 * port, so printf() appears on the PC through the board's own USB cable.
 * Taken from Embedded_System/Bare_Metal/platformIO/10_USART.
 */
void uart_dbg_init(void);
void uart_dbg_write(int ch);

#endif
