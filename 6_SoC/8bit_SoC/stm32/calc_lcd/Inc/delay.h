#ifndef DELAY_H
#define DELAY_H

#include <stdint.h>

/* Busy-wait delays on SysTick (HCLK). Not used from interrupt handlers. */
void delay_us(uint32_t us);
void delay_ms(uint32_t ms);

#endif
