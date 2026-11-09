#include "board.h"
#include "delay.h"

#define TICKS_PER_US  (BOARD_HCLK_HZ / 1000000U)

/* One SysTick count-down of 'ticks' core clocks (1 .. 2^24). */
static void systick_wait(uint32_t ticks)
{
    SysTick->CTRL = 0U;
    SysTick->LOAD = ticks - 1U;
    SysTick->VAL  = 0U;
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk;
    while (!(SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk)) {
    }
    SysTick->CTRL = 0U;
}

void delay_us(uint32_t us)
{
    while (us > 1000U) {
        systick_wait(1000U * TICKS_PER_US);
        us -= 1000U;
    }
    if (us != 0U) {
        systick_wait(us * TICKS_PER_US);
    }
}

void delay_ms(uint32_t ms)
{
    while (ms-- != 0U) {
        systick_wait(1000U * TICKS_PER_US);
    }
}
