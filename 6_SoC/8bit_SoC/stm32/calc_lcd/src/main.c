/*
 * 8bit SoC - STM32 receiver (NUCLEO-F439ZI, bare-metal CMSIS)
 *
 * The FPGA calculator answers each operation line with one ASCII reply line
 * ending in CR LF, at most 15 characters (02_design/calculator.md), e.g.
 * "ADD:30", "DIV Q:-10 R:-10", "ERR DIV0". The same FPGA TX wire goes to the
 * PC's USB-UART adapter and to this board's USART6 RX (PG9, Arduino D0).
 *
 * This program shows the latest reply on the 16x2 I2C LCD:
 *   row 0: latest reply, row 1: blank (only the current result is shown).
 * A line ends only with CR followed by LF; the line is shown when that LF
 * comes. A line with a UART receive error, a line that ends with LF alone or
 * with CR not followed by LF, or a line in which bytes were lost (receive
 * buffer full) shows as "RX ERR"; a line longer than 16 characters shows as
 * "RX LONG". Empty lines (CR LF or LF alone) are ignored. The STM32 never
 * sends to the FPGA and does not interpret or recompute the replies.
 * Every line, plus start-up information, also goes to the ST-LINK virtual
 * COM port (USART3, 115200 8N1), after the LCD write:
 *   "#n FPGA> <reply>", "#n RX ERR (...)", "#n RX LONG (...)"
 * and with "LCD_FAIL " after "#n " when the LCD did not show it (no LCD
 * found at start-up, or the write and its retry failed).
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

static int write_rows(const char *row0, const char *row1)
{
    int err = lcd_write_line(0U, row0);
    if (err == I2C1_OK) {
        err = lcd_write_line(1U, row1);
    }
    return err;
}

/* Show two rows; returns 1 when the LCD shows them. If the write fails (e.g.
   a wire was moved with the power on and the I2C bus is stuck), free the bus,
   initialise the LCD again (it may also have lost power) and write once more.
   Without an LCD found at start-up nothing is written and 0 is returned. */
static int show(const char *row0, const char *row1)
{
    if (lcd_addr == 0U) {
        return 0;
    }
    int err = lcd_ready ? write_rows(row0, row1) : I2C1_ERR_TIME;
    if (err == I2C1_OK) {
        return 1;
    }
    int first = err;
    uint32_t sda = i2c1_recover();
    err = lcd_init(lcd_addr);
    if (err == I2C1_OK) {
        err = write_rows(row0, row1);
    }
    lcd_ready = (err == I2C1_OK);
    if (lcd_ready) {
        printf("LCD_RECOVERED first_err=%d sda_before=%lu\r\n", first, (unsigned long)sda);
    } else {
        printf("LCD_WRITE_FAIL first_err=%d retry_err=%d sda_before=%lu\r\n",
               first, err, (unsigned long)sda);
    }
    return lcd_ready;
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

/* the line being received */
static char     line[LINE_MAX + 1U];
static char     latest[LINE_MAX + 1U];
static uint32_t len;
static int      line_err;       /* UART error, wrong line end or lost bytes */
static int      line_long;      /* more than LINE_MAX characters */
static int      line_eol;       /* ended with LF alone, or CR not followed by LF */
static int      line_lost;      /* bytes of the line were lost (buffer full) */
static uint32_t count;

/* Show and print the line received so far, then start a new one. An empty
   line without an error is ignored. The debug line is printed after the LCD
   write, so it can say whether the LCD shows it. */
static void end_line(void)
{
    if (len == 0U && !line_err && !line_long) {
        return;
    }
    line[len] = '\0';
    count++;
    if (line_err) {
        uart_fpga_errors_t e;
        uart_fpga_get_errors(&e);
        strcpy(latest, "RX ERR");
        int shown = show(latest, "");
        printf("#%lu %sRX ERR (got \"%s\")%s%s pe=%lu fe=%lu nf=%lu ore=%lu drop=%lu\r\n",
               (unsigned long)count, shown ? "" : "LCD_FAIL ", line,
               line_eol ? " eol" : "", line_lost ? " lost" : "",
               (unsigned long)e.parity, (unsigned long)e.framing,
               (unsigned long)e.noise, (unsigned long)e.overrun,
               (unsigned long)e.dropped);
    } else if (line_long) {
        strcpy(latest, "RX LONG");
        int shown = show(latest, "");
        printf("#%lu %sRX LONG (first 16: \"%s\")\r\n", (unsigned long)count,
               shown ? "" : "LCD_FAIL ", line);
    } else {
        strcpy(latest, line);
        int shown = show(latest, "");
        printf("#%lu %sFPGA> %s\r\n", (unsigned long)count, shown ? "" : "LCD_FAIL ", line);
    }
    len = 0U;
    line_err = 0;
    line_long = 0;
    line_eol = 0;
    line_lost = 0;
}

int main(void)
{
    int cr_seen = 0;            /* the line got its CR and waits for the LF */

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
#ifdef I2C_RECOVER_SELFTEST
    lcd_ready = 0;          /* test build: force the recovery path once (README) */
#endif
    show("8bit SoC calc", "waiting UART...");

    uart_fpga_init();
    printf("USART6 RX PG9 (D0) 115200 8E1 ready\r\n");

    for (;;) {
        uint16_t entry;

        if (!uart_fpga_get(&entry)) {
            continue;
        }
        int lost = (entry & UART_FPGA_LOST) != 0U;
        char c = (char)(entry & 0xFFU);

        /* Line end rule (02_design/calculator.md 3): CR then LF. */
        if (cr_seen) {
            cr_seen = 0;
            if (!lost && c == '\n') {
                if (entry & UART_FPGA_ERR) {
                    line_err = 1;
                }
                end_line();
                continue;
            }
            /* CR not followed by LF: the line breaks the rule. This entry
               then starts the next line. */
            line_err = 1;
            line_eol = 1;
            if (lost) {
                line_lost = 1;
            }
            end_line();
        }
        if (lost) {
            /* bytes went missing here: the line being received is damaged */
            line_err = 1;
            line_lost = 1;
            continue;
        }
        if (entry & UART_FPGA_ERR) {
            line_err = 1;
        }
        if (c == '\r') {
            cr_seen = 1;
        } else if (c == '\n') {
            /* LF without CR: an error, unless the line is empty */
            if (len > 0U || line_err || line_long) {
                line_err = 1;
                line_eol = 1;
            }
            end_line();
        } else if (len < LINE_MAX) {
            line[len++] = c;
        } else {
            line_long = 1;
        }
    }
}
