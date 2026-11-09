#ifndef I2C1_H
#define I2C1_H

#include <stdint.h>

/*
 * I2C1 master, 100 kHz standard mode.
 * PB8 = SCL (Arduino D15), PB9 = SDA (Arduino D14), AF4, open drain.
 * Internal pull-ups on: the LCD shield has none of its own. The bus high
 * level is therefore 3.3 V; the 5 V PCF8574 on the shield accepted it on the
 * board (2026-11-09) although its data-sheet minimum is 0.7 x VDD.
 */
#define I2C1_OK        0
#define I2C1_ERR_BUSY  (-1)    /* bus stayed busy (SDA or SCL held low) */
#define I2C1_ERR_NACK  (-2)    /* no acknowledge from the device */
#define I2C1_ERR_TIME  (-3)    /* a step did not finish in time */

void i2c1_init(void);

/*
 * Free a stuck bus and restart I2C1: up to 9 SCL pulses by GPIO until the
 * device releases SDA, a STOP condition, then i2c1_init() (which also resets
 * the I2C1 block, clearing a stuck BUSY flag). Used after a failed write,
 * e.g. when a wire was plugged in with the power on. Returns the SDA level
 * seen before the pulses (0 = a device was holding SDA low).
 */
uint32_t i2c1_recover(void);

int  i2c1_write(uint8_t addr7, const uint8_t *data, uint32_t len);
int  i2c1_probe(uint8_t addr7);   /* address only: I2C1_OK when acknowledged */

#endif
