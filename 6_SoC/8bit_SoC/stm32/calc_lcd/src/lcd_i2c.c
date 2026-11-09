#include <stdint.h>
#include "delay.h"
#include "i2c1.h"
#include "lcd_i2c.h"

/*
 * PCF8574 output bits -> LCD pins. This is the usual map of these I2C LCD
 * boards (the same one the Arduino LiquidCrystal_I2C library assumes):
 *   P0 = RS, P1 = R/W, P2 = EN, P3 = backlight, P4..P7 = D4..D7.
 * If the screen stays blank while the I2C address answers, check this map
 * against the module first.
 */
#define LCD_RS         0x01U
#define LCD_RW         0x02U
#define LCD_EN         0x04U
#define LCD_BACKLIGHT  0x08U
#define LCD_D4_SHIFT   4U

/* HD44780 commands */
#define CMD_CLEAR        0x01U
#define CMD_ENTRY_INC    0x06U   /* cursor moves right, no display shift */
#define CMD_DISPLAY_OFF  0x08U
#define CMD_DISPLAY_ON   0x0CU   /* display on, cursor off, blink off */
#define CMD_FUNC_4BIT_2L 0x28U   /* 4-bit bus, 2 lines, 5x8 dots */
#define CMD_SET_DDRAM    0x80U
#define ROW1_DDRAM       0x40U

static uint8_t lcd_addr;

/*
 * One 4-bit transfer: put RS and the data on the pins, raise EN, lower EN.
 * Each I2C byte takes about 90 us at 100 kHz, longer than the HD44780 setup
 * time and the 450 ns EN pulse width.
 */
static int lcd_nibble(uint8_t nibble, uint8_t rs)
{
    uint8_t b = (uint8_t)(((nibble & 0x0FU) << LCD_D4_SHIFT) | LCD_BACKLIGHT | rs);
    uint8_t seq[3] = { b, (uint8_t)(b | LCD_EN), b };

    return i2c1_write(lcd_addr, seq, 3U);
}

static int lcd_byte(uint8_t value, uint8_t rs)
{
    int err = lcd_nibble((uint8_t)(value >> 4U), rs);

    if (err == I2C1_OK) {
        err = lcd_nibble(value, rs);
    }
    delay_us(50U);                          /* most commands need 37 us */
    return err;
}

static int lcd_command(uint8_t cmd)
{
    int err = lcd_byte(cmd, 0U);

    if (cmd == CMD_CLEAR) {
        delay_ms(2U);                       /* clear needs 1.52 ms */
    }
    return err;
}

uint8_t lcd_find_address(void)
{
    /* PCF8574: 0x20..0x27, PCF8574A: 0x38..0x3F; the factory default
       (A0..A2 open, pulled high) is 0x27 or 0x3F, so try those first. */
    static const uint8_t first[] = { 0x27U, 0x3FU };

    for (uint32_t i = 0U; i < sizeof first; i++) {
        if (i2c1_probe(first[i]) == I2C1_OK) {
            return first[i];
        }
    }
    for (uint8_t a = 0x20U; a <= 0x3FU; a++) {
        if (a == 0x28U) {
            a = 0x38U;
        }
        if (i2c1_probe(a) == I2C1_OK) {
            return a;
        }
    }
    return 0U;
}

int lcd_init(uint8_t addr7)
{
    int err;

    lcd_addr = addr7;
    delay_ms(50U);                          /* > 40 ms after the LCD supply rises */

    /* Reset by instruction (HD44780 figure 24): three times 0x3, then 0x2
       selects the 4-bit bus whatever state the controller was left in. */
    err = lcd_nibble(0x3U, 0U); delay_ms(5U);
    if (err == I2C1_OK) { err = lcd_nibble(0x3U, 0U); delay_ms(1U); }
    if (err == I2C1_OK) { err = lcd_nibble(0x3U, 0U); delay_ms(1U); }
    if (err == I2C1_OK) { err = lcd_nibble(0x2U, 0U); delay_ms(1U); }

    if (err == I2C1_OK) { err = lcd_command(CMD_FUNC_4BIT_2L); }
    if (err == I2C1_OK) { err = lcd_command(CMD_DISPLAY_OFF); }
    if (err == I2C1_OK) { err = lcd_command(CMD_CLEAR); }
    if (err == I2C1_OK) { err = lcd_command(CMD_ENTRY_INC); }
    if (err == I2C1_OK) { err = lcd_command(CMD_DISPLAY_ON); }
    return err;
}

int lcd_write_line(uint8_t row, const char *text)
{
    int err = lcd_command((uint8_t)(CMD_SET_DDRAM | (row != 0U ? ROW1_DDRAM : 0x00U)));
    uint32_t i = 0U;

    /* Write all 16 cells so the rest of an older, longer line is cleared. */
    for (uint32_t col = 0U; col < LCD_COLS && err == I2C1_OK; col++) {
        char c = ' ';
        if (text[i] != '\0') {
            c = text[i++];
            if (c < 0x20 || c > 0x7E) {
                c = '?';                    /* only printable ASCII on the LCD */
            }
        }
        err = lcd_byte((uint8_t)c, LCD_RS);
    }
    return err;
}
