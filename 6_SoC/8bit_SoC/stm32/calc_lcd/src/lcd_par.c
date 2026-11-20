#ifdef LCD_PARALLEL
/*
 * 16x2 character LCD (HD44780-compatible) driven directly in 4-bit parallel
 * mode, Arduino LCD-keypad-shield wiring (LiquidCrystal(8, 9, 4, 5, 6, 7)):
 *   RS = D8 (PF12), EN = D9 (PD15), D4..D7 = D4 (PF14), D5 (PE11),
 *   D6 (PE9), D7 (PF13); R/W is tied low on the shield.
 * Same interface as lcd_i2c.c; build with -DLCD_PARALLEL to use this one.
 * The 3.3 V outputs meet the HD44780 input-high level (2.2 V at 5 V supply).
 */
#include <stdint.h>
#include "board.h"
#include "delay.h"
#include "i2c1.h"
#include "lcd_i2c.h"

typedef struct { GPIO_TypeDef *port; uint8_t pin; } lcd_pin_t;

static const lcd_pin_t PIN_RS = { GPIOF, 12U };
static const lcd_pin_t PIN_EN = { GPIOD, 15U };
static const lcd_pin_t PIN_D[4] = { { GPIOF, 14U }, { GPIOE, 11U }, { GPIOE, 9U }, { GPIOF, 13U } };

static void pin_output(lcd_pin_t p)
{
    p.port->BSRR  = 1U << (p.pin + 16U);                   /* start low */
    p.port->MODER = (p.port->MODER & ~(3U << (p.pin * 2U))) | (1U << (p.pin * 2U));
}

static void pin_set(lcd_pin_t p, uint32_t v)
{
    p.port->BSRR = v ? (1U << p.pin) : (1U << (p.pin + 16U));
}

static void lcd_nibble(uint8_t nibble, uint8_t rs)
{
    pin_set(PIN_RS, rs);
    for (uint32_t i = 0U; i < 4U; i++) {
        pin_set(PIN_D[i], (nibble >> i) & 1U);
    }
    delay_us(1U);
    pin_set(PIN_EN, 1U);
    delay_us(1U);
    pin_set(PIN_EN, 0U);
    delay_us(1U);
}

static void lcd_byte(uint8_t value, uint8_t rs)
{
    lcd_nibble((uint8_t)(value >> 4U), rs);
    lcd_nibble((uint8_t)(value & 0x0FU), rs);
    delay_us(50U);
}

static void lcd_command(uint8_t cmd)
{
    lcd_byte(cmd, 0U);
    if (cmd == 0x01U) {
        delay_ms(2U);
    }
}

uint8_t lcd_find_address(void)
{
    return 0xFFU;                                           /* no I2C address */
}

int lcd_init(uint8_t addr7)
{
    (void)addr7;
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIODEN | RCC_AHB1ENR_GPIOEEN | RCC_AHB1ENR_GPIOFEN;
    (void)RCC->AHB1ENR;
    pin_output(PIN_RS);
    pin_output(PIN_EN);
    for (uint32_t i = 0U; i < 4U; i++) {
        pin_output(PIN_D[i]);
    }

    delay_ms(50U);
    lcd_nibble(0x3U, 0U); delay_ms(5U);
    lcd_nibble(0x3U, 0U); delay_ms(1U);
    lcd_nibble(0x3U, 0U); delay_ms(1U);
    lcd_nibble(0x2U, 0U); delay_ms(1U);
    lcd_command(0x28U);     /* 4-bit, 2 lines */
    lcd_command(0x08U);     /* display off */
    lcd_command(0x01U);     /* clear */
    lcd_command(0x06U);     /* entry: increment */
    lcd_command(0x0CU);     /* display on */
    return I2C1_OK;
}

int lcd_write_line(uint8_t row, const char *text)
{
    uint32_t i = 0U;

    lcd_command((uint8_t)(0x80U | (row != 0U ? 0x40U : 0x00U)));
    for (uint32_t col = 0U; col < LCD_COLS; col++) {
        char c = ' ';
        if (text[i] != '\0') {
            c = text[i++];
            if (c < 0x20 || c > 0x7E) {
                c = '?';
            }
        }
        lcd_byte((uint8_t)c, 1U);
    }
    return I2C1_OK;
}
#endif
