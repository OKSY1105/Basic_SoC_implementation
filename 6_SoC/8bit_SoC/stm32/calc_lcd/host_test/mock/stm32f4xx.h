#ifndef HOST_STM32F4XX_H
#define HOST_STM32F4XX_H

/*
 * Host-test stand-in for the CMSIS device header: only the registers, bits
 * and calls that src/main.c and src/uart_fpga.c use. The registers are plain
 * variables in host_mocks.c; the bit positions are those of RM0090.
 */
#include <stdint.h>

typedef struct { volatile uint32_t SR, DR, BRR, CR1, CR2, CR3, GTPR; } USART_TypeDef;
typedef struct { volatile uint32_t MODER, OTYPER, OSPEEDR, PUPDR, IDR, ODR, BSRR, LCKR, AFR[2]; } GPIO_TypeDef;
typedef struct { volatile uint32_t AHB1ENR, APB1ENR, APB2ENR; } RCC_TypeDef;

extern USART_TypeDef host_usart6;
extern GPIO_TypeDef  host_gpiob, host_gpiog;
extern RCC_TypeDef   host_rcc;
extern uint32_t      SystemCoreClock;

#define USART6  (&host_usart6)
#define GPIOB   (&host_gpiob)
#define GPIOG   (&host_gpiog)
#define RCC     (&host_rcc)

#define RCC_AHB1ENR_GPIOGEN   (1U << 6)
#define RCC_APB2ENR_USART6EN  (1U << 5)

#define USART_SR_PE      (1U << 0)
#define USART_SR_FE      (1U << 1)
#define USART_SR_NE      (1U << 2)
#define USART_SR_ORE     (1U << 3)
#define USART_SR_RXNE    (1U << 5)
#define USART_CR1_RE     (1U << 2)
#define USART_CR1_RXNEIE (1U << 5)
#define USART_CR1_PCE    (1U << 10)
#define USART_CR1_M      (1U << 12)
#define USART_CR1_UE     (1U << 13)

typedef enum { USART6_IRQn = 71 } IRQn_Type;

static inline void NVIC_SetPriority(IRQn_Type irq, uint32_t prio) { (void)irq; (void)prio; }
static inline void NVIC_EnableIRQ(IRQn_Type irq) { (void)irq; }
static inline void __disable_irq(void) { }
static inline void __enable_irq(void) { }
static inline void SystemCoreClockUpdate(void) { }

#endif
