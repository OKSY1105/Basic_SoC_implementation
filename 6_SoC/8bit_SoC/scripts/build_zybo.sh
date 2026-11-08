#!/usr/bin/env bash
# Zybo Z7-20 bitstream of the 8bit SoC (WSL/Linux Vivado, batch).
# Usage: bash scripts/build_zybo.sh [BUILD_DIR]
#   BUILD_DIR  output folder outside the repository (default /tmp/zybo_build)
#   VIVADO_BIN Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
# Steps: assemble firmware/calc.asm to BUILD_DIR/calc.mem, then run
# scripts/build_zybo.tcl (synthesis, placement, routing, reports, bitstream
# BUILD_DIR/soc8_zybo_top.bit). Program the board from WSL with
# scripts/program_zybo.sh (keep the bitstream outside /tmp, e.g. /home/sean/zybo_build).
# Exit status 0 only if the log has SOC8_ZYBO_BUILD_PASS.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S8=$(dirname "$here")
R=$(cd "$S8/../.." && pwd)
C=$R/1_RTL/2_TINY_PROJECT/CPU/8bit_CPU
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
B=${1:-/tmp/zybo_build}

rm -rf "$B" && mkdir -p "$B" && cd "$B" || exit 1
python3 -I "$C/TOOLS/cpu8_asm.py" "$S8/firmware/calc.asm" -o "$B/calc.mem" || exit 1
SOC8_BUILD="$B" SOC8_ROM_FILE="$B/calc.mem" "$V/vivado" -mode batch -nojournal \
    -log "$B/build.log" -source "$S8/scripts/build_zybo.tcl" > /dev/null
code=$?
grep -E "^(SOC8_ZYBO_|ERROR)" "$B/build.log"
echo "critical_warnings=$(grep -c '^CRITICAL WARNING' "$B/build.log")"
grep -q "^SOC8_ZYBO_BUILD_PASS" "$B/build.log" && [ $code -eq 0 ] && { echo "RESULT status=0 logs=$B"; exit 0; }
echo "RESULT status=1 logs=$B"
exit 1
