#!/usr/bin/env bash
# One command for the calculator board test page (Ubuntu on WSL2):
# attaches the USB-UART adapter and the Nucleo ST-LINK to WSL, starts
# pc_tools/calc_ui.py and opens the page in a window on the Windows screen.
# Usage: bash scripts/calc_ui.sh            (FPGA TX wired to the STM32 D0 only:
#                                            replies read from the STM32 output)
#        bash scripts/calc_ui.sh --reply-from pc   (FPGA TX also wired to the adapter RX)
#        other options are passed to calc_ui.py (python3 pc_tools/calc_ui.py --help)
# Stop with Ctrl+C in this terminal. If the page is already running, this only
# opens its window again.
set -u
cd "$(dirname "$0")/.." || exit 1

if pgrep -f 'pc_tools/calc_ui.py' >/dev/null; then
    echo "calc_ui.py is already running; opening its page again (stop it with Ctrl+C in its terminal)"
    exec python3 -c 'import sys; sys.path.insert(0, "pc_tools"); import calc_ui; print(calc_ui.open_window("http://localhost:8765") or "open http://localhost:8765")'
fi
if pgrep -af 'miniterm|calc_board_test' >/dev/null; then
    echo "ERROR: another program uses a serial port (miniterm or calc_board_test.py). Close it first:"
    pgrep -af 'miniterm|calc_board_test'
    exit 1
fi

bash scripts/wsl_usb.sh attach 0403:6001 || { echo "ERROR: USB-UART adapter (0403:6001) not attached"; exit 1; }
reply=stm32
if ! bash scripts/wsl_usb.sh attach 0483:374b; then
    echo "STM32 ST-LINK not attached: running without the STM32/LCD comparison"
    reply=pc
fi
for _ in $(seq 1 20); do ls /dev/ttyUSB* >/dev/null 2>&1 && break; sleep 0.25; done

exec python3 pc_tools/calc_ui.py --reply-from "$reply" "$@"
