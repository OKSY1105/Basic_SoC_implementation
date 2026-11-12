#!/usr/bin/env bash
# Host test of the STM32 receiver (see host_test.c): builds the real
# src/main.c and src/uart_fpga.c with the PC's gcc, AddressSanitizer and
# UndefinedBehaviorSanitizer, with fake registers, LCD and I2C, and runs the
# cases. No board is needed.
# Usage: bash host_test/run_host_test.sh [BUILD_DIR]   (default: a new folder under /tmp)
# Prints one HOST_CASE line per case and STM32_HOST_PASS / STM32_HOST_FAIL.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
P=$(dirname "$here")
B=${1:-$(mktemp -d /tmp/calc_lcd_host.XXXXXX)}
mkdir -p "$B"
CC=${CC:-gcc}
F="-std=c11 -Wall -Wextra -Werror -g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all"
I="-I$here/mock -I$P/Inc -I$here"
$CC $F $I -Dmain=stm32_main -Duart_fpga_get=host_uart_get -c "$P/src/main.c" -o "$B/main.o"
$CC $F $I -c "$P/src/uart_fpga.c" -o "$B/uart_fpga.o"
$CC $F $I -c "$here/host_mocks.c" -o "$B/host_mocks.o"
$CC $F $I -c "$here/host_test.c" -o "$B/host_test.o"
$CC $F "$B/main.o" "$B/uart_fpga.o" "$B/host_mocks.o" "$B/host_test.o" -o "$B/host_test"
"$B/host_test"
