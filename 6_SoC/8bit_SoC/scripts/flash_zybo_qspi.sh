#!/usr/bin/env bash
# Write the 8bit SoC QSPI boot image to the Zybo Z7-20 flash from Ubuntu
# (WSL2): attach the board (scripts/wsl_usb.sh), check its USB node, then run
# scripts/flash_zybo_qspi.tcl with the Linux Vivado in batch mode
# (erase, program, verify).
# Usage: bash scripts/flash_zybo_qspi.sh [--detach] [BOOT_DIR]
#   BOOT_DIR    folder with BOOT.bin and fsbl/executable.elf
#               (default /home/sean/zybo_build/boot, made by scripts/build_zybo_boot.sh)
#   --detach    give the board back to the host afterwards
#   VIVADO_BIN  Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
#   FLASH_TIMEOUT  seconds before a stuck run is stopped (default 600; a normal run takes about 210)
# Before it: JP5 on JTAG and a power cycle (Vivado supports flash programming
# in JTAG boot mode only; in QSPI mode a second write stopped before the FSBL
# download on 2026-11-09). After it passes: power off (SW4), move JP5 to QSPI
# (two center pins), power on; the FSBL configures the PL (LD12 DONE, then LD0
# and LD1 on). The log is kept as BOOT_DIR/flash_<date>_<time>.log.
# Exit status 0 only if the log has SOC8_ZYBO_QSPI_PASS.
set -u
here=$(cd "$(dirname "$0")" && pwd)
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
BOARD=0403:6010
detach=0
dir=/home/sean/zybo_build/boot
for a in "$@"; do
    case "$a" in
        --detach) detach=1 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        -*) echo "ERROR: unknown option $a" >&2; exit 1 ;;
        *) dir=$a ;;
    esac
done
boot=$dir/BOOT.bin
fsbl=$dir/fsbl/executable.elf
for f in "$boot" "$fsbl"; do
    [ -f "$f" ] || { echo "ERROR: $f not found (bash $here/build_zybo_boot.sh)" >&2; exit 1; }
done
[ -x "$V/vivado" ] || { echo "ERROR: Vivado not found: $V/vivado" >&2; exit 1; }

bash "$here/wsl_usb.sh" attach "$BOARD" || exit 1
VIVADO_BIN=$V bash "$here/wsl_usb.sh" node "$BOARD" || exit 1

timeout_s=${FLASH_TIMEOUT:-600}
log=$dir/flash_$(date +%Y%m%d_%H%M%S).log
work=$(mktemp -d /tmp/zybo_flash.XXXXXX) && cd "$work" || exit 1
# Own process group, so that a stuck run (Vivado and its xsdb) can be stopped as a whole.
setsid "$V/vivado" -mode batch -nojournal -nolog -notrace -source "$here/flash_zybo_qspi.tcl" \
    -tclargs "$boot" "$fsbl" > flash.log 2>&1 &
pid=$!
waited=0
timed_out=0
while kill -0 "$pid" 2>/dev/null; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge "$timeout_s" ]; then
        timed_out=1
        kill -TERM -- "-$pid" 2>/dev/null
        sleep 3
        kill -KILL -- "-$pid" 2>/dev/null
        break
    fi
done
wait "$pid" 2>/dev/null
code=$?
grep -E '^(SOC8_ZYBO_|ERROR)|Flash programming completed|Verify Operation|Elapsed time|SF: Detected' flash.log | head -20
cp -f flash.log "$log" 2>/dev/null
status=1
grep -q '^SOC8_ZYBO_QSPI_PASS' flash.log && [ $code -eq 0 ] && [ $timed_out -eq 0 ] && status=0
if [ $timed_out -eq 1 ]; then
    echo "ERROR: flash programming did not finish within $timeout_s s and was stopped." >&2
fi
if [ $status -ne 0 ] && grep -q 'The current boot mode is QSPI' flash.log; then
    echo "NOTE: the board is in QSPI boot mode. Move JP5 to JTAG, power-cycle the board (SW4) and run this script again." >&2
fi

if [ $detach -eq 1 ]; then
    bash "$here/wsl_usb.sh" detach "$BOARD" || status=1
fi
echo "RESULT status=$status log=$log"
exit $status
