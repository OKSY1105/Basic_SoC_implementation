#!/usr/bin/env bash
# Program the Zybo Z7-20 PL with the 8bit SoC bitstream from Ubuntu (WSL2):
# attach the board's USB (FTDI FT2232H, 0403:6010) to WSL with
# scripts/wsl_usb.sh, then run scripts/program_zybo.tcl with the Linux Vivado
# Hardware Manager in batch mode.
# Usage: bash scripts/program_zybo.sh [--detach] [BITSTREAM]
#   BITSTREAM   default /home/sean/zybo_build/soc8_zybo_top.bit
#               (build: bash scripts/build_zybo.sh /home/sean/zybo_build)
#   --detach    give the board back to the host after programming
#   VIVADO_BIN  Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
# Requirements (see fpga/boards/zybo/README.md "보드에 올리기"): the board
#   shared once in usbipd-win (usbipd bind, administrator), and its USB node
#   writable by this user through a udev rule. The script checks the node
#   after attaching and stops with the install command of the Xilinx cable
#   rules only when it is not writable (on the work PC the existing PlatformIO
#   rule already makes 0403:6010 mode 0666).
# Board: J12 micro-USB connected and power on; boot-mode jumper JP5 on JTAG
# is recommended. Vivado runs in a new folder under /tmp; the log path is printed.
# Exit status 0 only if the log has SOC8_ZYBO_PROGRAM_PASS.
set -u
here=$(cd "$(dirname "$0")" && pwd)
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
BOARD=0403:6010
detach=0
bit=/home/sean/zybo_build/soc8_zybo_top.bit
for a in "$@"; do
    case "$a" in
        --detach) detach=1 ;;
        -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
        -*) echo "ERROR: unknown option $a" >&2; exit 1 ;;
        *) bit=$a ;;
    esac
done

[ -f "$bit" ] || { echo "ERROR: bitstream not found: $bit (build: bash $here/build_zybo.sh /home/sean/zybo_build)" >&2; exit 1; }
[ -x "$V/vivado" ] || { echo "ERROR: Vivado not found: $V/vivado" >&2; exit 1; }

bash "$here/wsl_usb.sh" attach "$BOARD" || exit 1

# hw_server runs as this user, so the board's USB node must be writable.
node=""
for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    [ "$(cat "$d/idVendor"):$(cat "$d/idProduct")" = "$BOARD" ] || continue
    node=$(printf '/dev/bus/usb/%03d/%03d' "$(cat "$d/busnum")" "$(cat "$d/devnum")")
done
[ -n "$node" ] || { echo "ERROR: $BOARD is attached but not found in /sys/bus/usb/devices" >&2; exit 1; }
for _ in $(seq 1 20); do [ -w "$node" ] && break; sleep 0.25; done
if [ ! -w "$node" ]; then
    echo "ERROR: $node ($BOARD) is not writable by $(id -un): $(ls -l "$node")" >&2
    echo "Install a udev rule for the cable once (copies three rule files to /etc/udev/rules.d):" >&2
    echo "  cd $V/../data/xicom/cable_drivers/lin64/install_script/install_drivers && sudo ./install_drivers" >&2
    echo "then re-attach the board (bash $here/wsl_usb.sh detach $BOARD) and run this script again." >&2
    exit 1
fi
echo "JTAG_NODE $node writable by $(id -un)"

work=$(mktemp -d /tmp/zybo_program.XXXXXX) && cd "$work" || exit 1
"$V/vivado" -mode batch -nojournal -nolog -notrace -source "$here/program_zybo.tcl" -tclargs "$bit" > program.log 2>&1
code=$?
grep -E '^(SOC8_ZYBO_|ERROR|INFO: \[Labtools 27-3164\])' program.log
status=1
grep -q '^SOC8_ZYBO_PROGRAM_PASS' program.log && [ $code -eq 0 ] && status=0

if [ $detach -eq 1 ]; then
    bash "$here/wsl_usb.sh" detach "$BOARD" || status=1
fi
echo "RESULT status=$status log=$work/program.log"
exit $status
