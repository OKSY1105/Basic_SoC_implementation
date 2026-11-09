#ifndef LCD_I2C_H
#define LCD_I2C_H

#include <stdint.h>

/*
 * 16x2 character LCD (HD44780-compatible) behind a PCF8574-type I2C
 * expander, as on the YwRobot "LCM1602 IIC Shield V1".
 * The LCD runs in 4-bit mode and is only written (R/W kept low).
 * The expander bit map is in lcd_i2c.c (LCD_RS .. LCD_D4_SHIFT).
 */
#define LCD_COLS  16U
#define LCD_ROWS  2U

uint8_t lcd_find_address(void);      /* first acknowledging expander address, 0 = none */
int     lcd_init(uint8_t addr7);     /* I2C1_OK or an I2C1_ERR_* code */
int     lcd_write_line(uint8_t row, const char *text);  /* pads/cuts to 16 characters */

#endif
