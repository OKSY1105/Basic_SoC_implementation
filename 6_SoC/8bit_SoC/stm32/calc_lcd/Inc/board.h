#ifndef BOARD_H
#define BOARD_H

#include "stm32f4xx.h"

/*
 * Clock: the CMSIS start-up code leaves the chip on the internal 16 MHz HSI
 * (no PLL), and AHB, APB1 and APB2 are not divided. main() prints
 * SystemCoreClock so a different start-up clock shows at once.
 */
#define BOARD_HCLK_HZ   16000000U
#define BOARD_APB1_HZ   16000000U
#define BOARD_APB2_HZ   16000000U

#endif
