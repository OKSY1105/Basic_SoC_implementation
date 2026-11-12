/*
 * Fake hardware for the host test: register variables, and an LCD/I2C stand-in
 * that keeps the two rows and can fail writes on request. The real
 * lcd_i2c.c / i2c1.c / uart_dbg.c / delay.c are not used on the host.
 */
#include <stdio.h>
#include "stm32f4xx.h"
#include "i2c1.h"
#include "lcd_i2c.h"
#include "uart_dbg.h"
#include "host_mocks.h"

USART_TypeDef host_usart6;
GPIO_TypeDef  host_gpiob, host_gpiog;
RCC_TypeDef   host_rcc;
uint32_t      SystemCoreClock = 16000000U;

int mock_lcd_addr = 0x27;
int mock_write_fail;
int mock_writes;

static char rows[LCD_ROWS][LCD_COLS + 1U];

uint8_t lcd_find_address(void)
{
    return (uint8_t)mock_lcd_addr;
}

int lcd_init(uint8_t addr7)
{
    return (mock_lcd_addr != 0 && addr7 == mock_lcd_addr) ? I2C1_OK : I2C1_ERR_NACK;
}

int lcd_write_line(uint8_t row, const char *text)
{
    if (mock_write_fail > 0) {
        mock_write_fail--;
        return I2C1_ERR_NACK;
    }
    if (mock_lcd_addr == 0 || row >= LCD_ROWS) {
        return I2C1_ERR_NACK;
    }
    snprintf(rows[row], sizeof rows[row], "%.16s", text);
    mock_writes++;
    return I2C1_OK;
}

void i2c1_init(void) { }

uint32_t i2c1_recover(void)
{
    return 1U;
}

int i2c1_probe(uint8_t addr7)
{
    return (mock_lcd_addr != 0 && addr7 == mock_lcd_addr) ? I2C1_OK : I2C1_ERR_NACK;
}

void uart_dbg_init(void) { }

void mock_print_lcd(void)
{
    printf("@LCD row0=\"%s\" row1=\"%s\" writes=%d\n", rows[0], rows[1], mock_writes);
}
