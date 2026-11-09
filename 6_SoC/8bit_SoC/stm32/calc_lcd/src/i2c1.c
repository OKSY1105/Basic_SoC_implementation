#include <stddef.h>
#include <stdint.h>
#include "board.h"
#include "delay.h"
#include "i2c1.h"

#define I2C_SPEED_HZ   100000U
#define I2C_TIMEOUT    100000U   /* loop count; one 100 kHz byte is ~1,500 loops */

void i2c1_init(void)
{
    /* GPIOB clock; PB8/PB9 alternate function 4, open drain, pull-up */
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIOBEN;
    (void)RCC->AHB1ENR;
    GPIOB->MODER   = (GPIOB->MODER   & ~((3U << (8U * 2U)) | (3U << (9U * 2U))))
                   | (2U << (8U * 2U)) | (2U << (9U * 2U));
    GPIOB->OTYPER |= (1U << 8U) | (1U << 9U);
    GPIOB->OSPEEDR = (GPIOB->OSPEEDR & ~((3U << (8U * 2U)) | (3U << (9U * 2U))))
                   | (1U << (8U * 2U)) | (1U << (9U * 2U));
    /* The YwRobot LCM1602 IIC Shield has no SDA/SCL pull-ups (2026-11-09:
       the bus floated and nothing answered until these were turned on), so
       use the internal ones (about 40 kohm to 3.3 V). */
    GPIOB->PUPDR   = (GPIOB->PUPDR & ~((3U << (8U * 2U)) | (3U << (9U * 2U))))
                   | (1U << (8U * 2U)) | (1U << (9U * 2U));
    GPIOB->AFR[1]  = (GPIOB->AFR[1] & ~((0xFU << 0U) | (0xFU << 4U)))
                   | (4U << 0U) | (4U << 4U);

    /* I2C1 on APB1: reset, then standard mode */
    RCC->APB1ENR  |= RCC_APB1ENR_I2C1EN;
    (void)RCC->APB1ENR;
    RCC->APB1RSTR |= RCC_APB1RSTR_I2C1RST;
    RCC->APB1RSTR &= ~RCC_APB1RSTR_I2C1RST;

    I2C1->CR1   = 0U;
    I2C1->CR2   = BOARD_APB1_HZ / 1000000U;                 /* FREQ in MHz */
    I2C1->CCR   = BOARD_APB1_HZ / (2U * I2C_SPEED_HZ);      /* Sm: Thigh = Tlow = CCR * Tpclk */
    I2C1->TRISE = (BOARD_APB1_HZ / 1000000U) + 1U;          /* 1000 ns maximum rise time */
    I2C1->CR1   = I2C_CR1_PE;
}

#define SCL_BIT  8U
#define SDA_BIT  9U

static void bus_pin(uint32_t bit, uint32_t level)
{
    GPIOB->BSRR = level ? (1U << bit) : (1U << (bit + 16U));
    delay_us(5U);                               /* half of a 100 kHz clock */
}

uint32_t i2c1_recover(void)
{
    uint32_t sda_before;

    /* I2C1 off; PB8/PB9 as open-drain GPIO outputs, released (high). */
    I2C1->CR1 = 0U;
    GPIOB->BSRR  = (1U << SCL_BIT) | (1U << SDA_BIT);
    GPIOB->MODER = (GPIOB->MODER & ~((3U << (SCL_BIT * 2U)) | (3U << (SDA_BIT * 2U))))
                 | (1U << (SCL_BIT * 2U)) | (1U << (SDA_BIT * 2U));
    delay_us(5U);
    sda_before = (GPIOB->IDR >> SDA_BIT) & 1U;

    /* A device stopped in the middle of a byte holds SDA low; clock it out. */
    for (uint32_t i = 0U; i < 9U && !((GPIOB->IDR >> SDA_BIT) & 1U); i++) {
        bus_pin(SCL_BIT, 0U);
        bus_pin(SCL_BIT, 1U);
    }
    /* STOP: SDA low -> high while SCL is high. */
    bus_pin(SCL_BIT, 0U);
    bus_pin(SDA_BIT, 0U);
    bus_pin(SCL_BIT, 1U);
    bus_pin(SDA_BIT, 1U);

    i2c1_init();                                /* back to AF4, I2C1 block reset */
    return sda_before;
}

/* End a transfer after an error: STOP, then clear the acknowledge failure. */
static int i2c1_abort(int err)
{
    I2C1->CR1 |= I2C_CR1_STOP;
    I2C1->SR1 &= ~I2C_SR1_AF;
    return err;
}

/* Wait for an SR1 flag; a NACK or a timeout ends the transfer. */
static int i2c1_wait_sr1(uint32_t flag)
{
    uint32_t t = I2C_TIMEOUT;

    while (!(I2C1->SR1 & flag)) {
        if (I2C1->SR1 & I2C_SR1_AF) {
            return i2c1_abort(I2C1_ERR_NACK);
        }
        if (--t == 0U) {
            return i2c1_abort(I2C1_ERR_TIME);
        }
    }
    return I2C1_OK;
}

int i2c1_write(uint8_t addr7, const uint8_t *data, uint32_t len)
{
    uint32_t t;
    int err;

    /* The previous STOP must be sent and the bus free before a new START. */
    t = I2C_TIMEOUT;
    while ((I2C1->CR1 & I2C_CR1_STOP) || (I2C1->SR2 & I2C_SR2_BUSY)) {
        if (--t == 0U) {
            return I2C1_ERR_BUSY;
        }
    }

    I2C1->CR1 |= I2C_CR1_START;
    err = i2c1_wait_sr1(I2C_SR1_SB);
    if (err != I2C1_OK) {
        return err;
    }

    I2C1->DR = (uint32_t)addr7 << 1U;          /* write direction */
    err = i2c1_wait_sr1(I2C_SR1_ADDR);
    if (err != I2C1_OK) {
        return err;
    }
    (void)I2C1->SR1;                            /* SR1 then SR2 clears ADDR */
    (void)I2C1->SR2;

    for (uint32_t i = 0U; i < len; i++) {
        err = i2c1_wait_sr1(I2C_SR1_TXE);
        if (err != I2C1_OK) {
            return err;
        }
        I2C1->DR = data[i];
    }
    if (len != 0U) {
        err = i2c1_wait_sr1(I2C_SR1_BTF);      /* last byte sent and acknowledged */
        if (err != I2C1_OK) {
            return err;
        }
    }

    I2C1->CR1 |= I2C_CR1_STOP;
    return I2C1_OK;
}

int i2c1_probe(uint8_t addr7)
{
    return i2c1_write(addr7, NULL, 0U);
}
