#!/usr/bin/env bash
# Zybo Z7-20 QSPI boot image of the 8bit SoC (Ubuntu on WSL2):
# BOOT.bin = Zynq FSBL + the SoC bitstream + a PS program. At power-on with
# JP5 on QSPI, the Zynq BootROM runs the FSBL from the QSPI flash and the FSBL
# configures the PL with the bitstream, so the SoC comes up without JTAG
# programming. The FSBL is built for a bitstream without the PS7 block (it
# leaves the PL-to-PS level shifters off) and then hands off to the PS
# program (hello_world, waits in DDR). See scripts/zybo_fsbl.tcl.
# Usage: bash scripts/build_zybo_boot.sh [BITSTREAM]
#   BITSTREAM        default /home/sean/zybo_build/soc8_zybo_top.bit (scripts/build_zybo.sh)
#   ZYBO_BOOT_DIR    output folder (default /home/sean/zybo_build/boot)
#   ZYBO_BOARD_REPO  Digilent board files folder holding zybo-z7-20/A.0/
#                    (default /home/sean/xilinx_boards/board_files)
#   VIVADO_BIN       Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
#   VITIS_DIR        Vitis folder (default /home/sean/Vitis/2024.2)
# Steps: 1 PS-only platform XSA with the board preset (scripts/zybo_ps_platform.tcl)
#        2 FSBL and PS program from the XSA (scripts/zybo_fsbl.tcl, xsct -nodisp)
#        3 boot.bif and bootgen -arch zynq -> BOOT.bin (bitstream copied next to it)
# Next: write BOOT.bin to the flash with scripts/flash_zybo_qspi.sh.
# Exit status 0 only if all steps pass (SOC8_ZYBO_BOOT_PASS).
set -u
here=$(cd "$(dirname "$0")" && pwd)
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
VITIS=${VITIS_DIR:-/home/sean/Vitis/2024.2}
OUT=${ZYBO_BOOT_DIR:-/home/sean/zybo_build/boot}
BOARDS=${ZYBO_BOARD_REPO:-/home/sean/xilinx_boards/board_files}
bit=${1:-/home/sean/zybo_build/soc8_zybo_top.bit}
die() { echo "ERROR: $*" >&2; echo "RESULT status=1 dir=$OUT"; exit 1; }

[ -f "$bit" ] || die "bitstream not found: $bit (bash $here/build_zybo.sh /home/sean/zybo_build)"
[ -f "$BOARDS/zybo-z7-20/A.0/board.xml" ] || die "Zybo Z7-20 board files not found in $BOARDS/zybo-z7-20/A.0 (board.xml, part0_pins.xml, preset.xml from https://github.com/Digilent/vivado-boards/tree/master/new/board_files/zybo-z7-20/A.0)"
[ -x "$V/vivado" ] && [ -x "$V/bootgen" ] || die "Vivado or bootgen not found in $V"
[ -f "$VITIS/settings64.sh" ] || die "Vitis not found: $VITIS/settings64.sh"
mkdir -p "$OUT" && cd "$OUT" || exit 1

echo "== 1 PS platform (XSA)"
ZYBO_BOOT_DIR="$OUT" ZYBO_BOARD_REPO="$BOARDS" "$V/vivado" -mode batch -nojournal -log "$OUT/xsa.log" \
    -source "$here/zybo_ps_platform.tcl" > /dev/null 2>&1
grep -E '^(ZYBO_PS_XSA_|ERROR)' "$OUT/xsa.log"
echo "critical_warnings=$(grep -c '^CRITICAL WARNING' "$OUT/xsa.log") (expected 4: PSU-1..4, negative DQS-to-clock delays of the board preset)"
grep -q '^ZYBO_PS_XSA_PASS' "$OUT/xsa.log" || die "XSA step failed (see $OUT/xsa.log)"

echo "== 2 FSBL and PS program"
# The Vitis settings script reads unset variables, so source it without set -u.
( set +u; source "$VITIS/settings64.sh" > /dev/null 2>&1
  xsct -nodisp "$here/zybo_fsbl.tcl" "$OUT/zybo_ps.xsa" "$OUT/fsbl" "$OUT/ps_app" ) > "$OUT/fsbl.log" 2>&1
grep -m1 -E '^ZYBO_FSBL_' "$OUT/fsbl.log"
grep -q '^ZYBO_FSBL_PASS' "$OUT/fsbl.log" || die "FSBL step failed (see $OUT/fsbl.log)"
for e in fsbl ps_app; do
    "$VITIS/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-size" "$OUT/$e/executable.elf" | tail -1 | \
        awk -v n="$e" '{print n "_size text=" $1 " data=" $2 " bss=" $3 " total=" $4}'
done

echo "== 3 BOOT.bin"
cp -f "$bit" "$OUT/soc8_zybo_top.bit" || die "cannot copy $bit"
cat > "$OUT/boot.bif" <<'BIF'
the_ROM_image:
{
	[bootloader] fsbl/executable.elf
	soc8_zybo_top.bit
	ps_app/executable.elf
}
BIF
rm -f "$OUT/BOOT.bin"
"$V/bootgen" -arch zynq -image boot.bif -o BOOT.bin -w on > "$OUT/bootgen.log" 2>&1
[ -f "$OUT/BOOT.bin" ] || { cat "$OUT/bootgen.log"; die "bootgen did not write BOOT.bin"; }
grep -E '^(ERROR|WARNING)' "$OUT/bootgen.log"
echo "SOC8_ZYBO_BOOT_PASS boot=$OUT/BOOT.bin bytes=$(stat -c %s "$OUT/BOOT.bin") fsbl=$OUT/fsbl/executable.elf bit_sha256=$(sha256sum "$OUT/soc8_zybo_top.bit" | cut -c1-16)"
echo "RESULT status=0 dir=$OUT"
