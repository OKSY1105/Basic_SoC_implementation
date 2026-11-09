/*
 * 8bit SoC - STM32 receiver (NUCLEO-F439ZI, bare-metal CMSIS)
 *
 * The FPGA calculator answers each operation line with one ASCII reply line
 * ending in CR LF, at most 15 characters (02_design/calculator.md), e.g.
 * "ADD:30", "DIV Q:-10 R:-10", "ERR DIV0". The same FPGA TX wire goes to the
 * PC's USB-UART adapter and to this board's USART6 RX (PG9, Arduino D0).
 *
 * This program shows the replies on the 16x2 I2C LCD:
 *   row 0: latest reply, row 1: the reply before it.
 * A line with a UART receive error shows as "RX ERR"; a line longer than
 * 16 characters shows as "RX LONG". The STM32 never sends to the FPGA and
 * does not interpret or recompute the replies.
 * Every line, plus start-up information, also goes to the ST-LINK virtual
 * COM port (USART3, 115200 8N1).
 */
#include <stdio.h>
#include <string.h>
#include "board.h"
#include "delay.h"
#include "i2c1.h"
#include "lcd_i2c.h"
#include "uart_dbg.h"
#include "uart_fpga.h"

#define LINE_MAX  LCD_COLS

static uint8_t lcd_addr;
static int     lcd_ready;

static void show(const char *row0, const char *row1)
{
    if (!lcd_ready) {
        return;
    }
    int err = lcd_write_line(0U, row0);
    if (err == I2C1_OK) {
        err = lcd_write_line(1U, row1);
    }
    if (err != I2C1_OK) {
        printf("LCD_WRITE_FAIL err=%d\r\n", err);
    }
}

static void i2c_scan(void)
{
    int found = 0;

    /* Idle bus level with the internal pull-ups: 0 means a line is held low
       (wrong pin, or the module is not powered). */
    printf("I2C1 idle level: SCL(PB8)=%lu SDA(PB9)=%lu\r\n",
           (unsigned long)((GPIOB->IDR >> 8U) & 1U), (unsigned long)((GPIOB->IDR >> 9U) & 1U));
    printf("I2C1 scan (PB8 SCL, PB9 SDA):");
    for (uint8_t a = 0x08U; a <= 0x77U; a++) {
        if (i2c1_probe(a) == I2C1_OK) {
            printf(" 0x%02X", a);
            found++;
        }
    }
    printf(found ? "\r\n" : " none\r\n");
}

int main(void)
{
    char line[LINE_MAX + 1U];
    char latest[LINE_MAX + 1U] = "";
    char previous[LINE_MAX + 1U] = "";
    uint32_t len = 0U;
    int line_err = 0;
    int line_long = 0;
    uint32_t count = 0U;

    SystemCoreClockUpdate();
    uart_dbg_init();
    printf("\r\n8bit SoC STM32 LCD receiver\r\n");
    printf("SystemCoreClock=%lu Hz (expected %lu)\r\n",
           (unsigned long)SystemCoreClock, (unsigned long)BOARD_HCLK_HZ);

    i2c1_init();
    i2c_scan();
    lcd_addr = lcd_find_address();
    if (lcd_addr == 0U) {
        printf("LCD_NOT_FOUND: no PCF8574 address answered (check SDA/SCL/VCC/GND)\r\n");
    } else {
        int err = lcd_init(lcd_addr);
        lcd_ready = (err == I2C1_OK);
        printf("LCD addr=0x%02X init=%s (err=%d)\r\n",
               lcd_addr, lcd_ready ? "OK" : "FAIL", err);
    }
    show("8bit SoC calc", "waiting UART...");

    uart_fpga_init();
    printf("USART6 RX PG9 (D0) 115200 8E1 ready\r\n");

    for (;;) {
        uint16_t entry;

        if (!uart_fpga_get(&entry)) {
            continue;
        }
        char c = (char)(entry & 0xFFU);
        if (entry & UART_FPGA_ERR) {
            line_err = 1;
        }

        if (c == '\r' || c == '\n') {
            /* CR ends the line; the LF of CR LF then gives an empty line,
               which is skipped unless it carried an error. */
            if (len == 0U && !line_err && !line_long) {
                continue;
            }
            line[len] = '\0';
            count++;

            strcpy(previous, latest);
            if (line_err) {
                uart_fpga_errors_t e;
                uart_fpga_get_errors(&e);
                strcpy(latest, "RX ERR");
                printf("#%lu RX ERR (got \"%s\") pe=%lu fe=%lu nf=%lu ore=%lu drop=%lu\r\n",
                       (unsigned long)count, line,
                       (unsigned long)e.parity, (unsigned long)e.framing,
                       (unsigned long)e.noise, (unsigned long)e.overrun,
                       (unsigned long)e.dropped);
            } else if (line_long) {
                strcpy(latest, "RX LONG");
                printf("#%lu RX LONG (first 16: \"%s\")\r\n", (unsigned long)count, line);
            } else {
                strcpy(latest, line);
                printf("#%lu FPGA> %s\r\n", (unsigned long)count, line);
            }
            show(latest, previous);

            len = 0U;
            line_err = 0;
            line_long = 0;
        } else if (len < LINE_MAX) {
            line[len++] = c;
        } else {
            line_long = 1;
        }
    }
}
