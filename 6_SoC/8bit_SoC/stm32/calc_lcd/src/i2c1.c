#include <stddef.h>
#include <stdint.h>
#include "board.h"
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
