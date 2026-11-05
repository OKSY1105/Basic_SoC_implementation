#!/usr/bin/env bash
# Board-level TB of soc8_zybo_top (WSL/Linux, Vivado XSim).
# Usage: bash scripts/run_zybo_top_tb.sh [BUILD_DIR]
#   BUILD_DIR  run folder outside the repository (default /tmp/zybo_top_tb)
#   VIVADO_BIN Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
# Steps: assemble firmware/calc.asm and tb/soc/programs/ram_basic.asm into
# BUILD_DIR, compile the SoC, the BRAM-based DRAM model, the board top and
# tb/board/tb_soc8_zybo_top.sv with the unisim library (MMCME2_BASE, BUFG)
# and glbl, and run two snapshots at 115200 bps:
#   calc  PROG=0: calculator firmware, protocol cases, BTN0 resets
#   ram   PROG=1: ram_basic, 256 bytes through cache + DRAM path, HALT
# Exit status 0 only if both logs have BOARD_TOP_PASS and no line starting
# with FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S8=$(dirname "$here")
R=$(cd "$S8/../.." && pwd)
L=$R/1_RTL/2_TINY_PROJECT
C=$L/CPU/8bit_CPU
U=$L/UART
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
B=${1:-/tmp/zybo_top_tb}

rm -rf "$B" && mkdir -p "$B" && cd "$B" || exit 1
python3 -I "$C/TOOLS/cpu8_asm.py" "$S8/firmware/calc.asm" -o "$B/calc.mem" || exit 1
python3 -I "$C/TOOLS/cpu8_asm.py" "$S8/tb/soc/programs/ram_basic.asm" -o "$B/ram_basic.mem" || exit 1
"$V/xvlog" "$V/../data/verilog/src/glbl.v" "$U/baud_rate_gen.v" "$U/fifo.v" "$U/uart_rx.v" \
    "$U/uart_tx.v" "$U/uart_top.v" "$L/DRAM/dram_bram_model.v" > xvlog_v.log 2>&1 || { grep ERROR xvlog_v.log; exit 1; }
"$V/xvlog" --sv -i "$C/RTL" \
    "$C/RTL/cpu8_alu.v" "$C/RTL/cpu8_decoder.v" "$C/RTL/cpu8_regfile.v" "$C/RTL/cpu8_top.v" \
    "$L/BUS/reset_sync.v" "$L/BUS/ahb_apb_bridge.v" "$L/Cache/cache.v" \
    "$L/DRAM_CONTEOLLER/dram_controller.v" \
    "$S8/rtl/bus/soc8_ahb_bus.v" "$S8/rtl/rom/soc8_rom.v" "$S8/rtl/uart/soc8_uart_apb.v" \
    "$S8/rtl/soc/soc8_top.v" "$S8/fpga/boards/zybo/soc8_zybo_top.v" "$S8/tb/board/tb_soc8_zybo_top.sv" \
    > xvlog_sv.log 2>&1 || { grep ERROR xvlog_sv.log; exit 1; }
"$V/xelab" --timescale 1ns/1ps -L unisims_ver tb_soc8_zybo_top glbl -s tb_calc > xelab_calc.log 2>&1 || { grep ERROR xelab_calc.log; exit 1; }
"$V/xelab" --timescale 1ns/1ps -L unisims_ver tb_soc8_zybo_top glbl -generic_top "PROG=1" \
    -s tb_ram > xelab_ram.log 2>&1 || { grep ERROR xelab_ram.log; exit 1; }
"$V/xsim" tb_calc -runall > sim_calc.log 2>&1
"$V/xsim" tb_ram -runall > sim_ram.log 2>&1

status=0
for run in calc ram; do
    echo "== $run"
    grep -E "^(CLOCK|COVER|BOARD_TOP_|FAIL)" "sim_$run.log"
    grep -q "^BOARD_TOP_PASS" "sim_$run.log" || status=1
    if grep -q "^FAIL" "sim_$run.log"; then status=1; fi
done
echo "RESULT status=$status logs=$B"
exit $status
