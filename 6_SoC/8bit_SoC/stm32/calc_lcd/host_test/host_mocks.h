#ifndef HOST_MOCKS_H
#define HOST_MOCKS_H

/* Fake LCD and I2C for the host test (host_mocks.c). */
extern int mock_lcd_addr;     /* address the fake expander answers on, 0 = no LCD */
extern int mock_write_fail;   /* this many next lcd_write_line() calls fail (NACK) */
extern int mock_writes;       /* lcd_write_line() calls that succeeded */

void mock_print_lcd(void);    /* prints "@LCD row0=... row1=... writes=N" */

#endif
