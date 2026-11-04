#!/usr/bin/env bash
# Integration TB of soc8_top (WSL/Linux, Vivado XSim).
# Usage: bash scripts/run_soc8_top_tb.sh [BUILD_DIR]
#   BUILD_DIR  run folder outside the repository (default /tmp/soc8_top_tb)
#   VIVADO_BIN Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
#   SOC8_DRAM_MODEL  dram (default: behavioral dram.v through
#              sim/models/soc8_dram_model.v) or bram (board model
#              DRAM/dram_bram_model.v wired as on the board, -d SOC8_BRAM_DRAM)
# Steps: assemble tb/soc/programs/*.asm, compile with the AHB/APB/CPU SVA
# checkers, run two snapshots:
#   fast  BAUD=3125000 (32 clocks per bit), FULL=1: all tests
#   real  BAUD=115200, FULL=0: ram_basic, uart_echo_irq (8 bytes, sender
#         clock nominal and 1.5% fast) and calc without the random lines
# Exit status 0 only if both logs have SOC8_TOP_PASS and no line starting
# with FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S8=$(dirname "$here")
R=$(cd "$S8/../.." && pwd)
L=$R/1_RTL/2_TINY_PROJECT
C=$L/CPU/8bit_CPU
U=$L/UART
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
B=${1:-/tmp/soc8_top_tb}
M=${SOC8_DRAM_MODEL:-dram}
case $M in
    dram) mdef="" ;;
    bram) mdef="-d SOC8_BRAM_DRAM" ;;
    *) echo "SOC8_DRAM_MODEL must be dram or bram"; exit 1 ;;
esac

rm -rf "$B" && mkdir -p "$B/programs" && cd "$B" || exit 1
for f in "$S8"/tb/soc/programs/*.asm "$S8"/firmware/*.asm; do
    python3 -I "$C/TOOLS/cpu8_asm.py" "$f" -o "$B/programs/$(basename "$f" .asm).mem" || exit 1
done
"$V/xvlog" "$U/baud_rate_gen.v" "$U/fifo.v" "$U/uart_rx.v" "$U/uart_tx.v" "$U/uart_top.v" \
    "$L/DRAM/dram.v" "$L/DRAM/dram_bram_model.v" > xvlog_v.log 2>&1 || { grep ERROR xvlog_v.log; exit 1; }
"$V/xvlog" --sv $mdef -d AHB_LITE_SVA -d APB_SVA -d CPU8_SVA -i "$C/RTL" \
    "$C/RTL/cpu8_alu.v" "$C/RTL/cpu8_decoder.v" "$C/RTL/cpu8_regfile.v" "$C/RTL/cpu8_top.v" \
    "$C/TB/cpu8_ahb_checker.sv" "$C/TB/cpu8_irq_checker.sv" \
    "$L/BUS/reset_sync.v" "$L/BUS/ahb_apb_bridge.v" "$L/BUS/ahb_lite_slave_checker.sv" \
    "$L/BUS/apb_checker.sv" "$L/Cache/cache.v" "$L/DRAM_CONTEOLLER/dram_controller.v" \
    "$S8/rtl/bus/soc8_ahb_bus.v" "$S8/rtl/rom/soc8_rom.v" "$S8/rtl/uart/soc8_uart_apb.v" \
    "$S8/rtl/soc/soc8_top.v" "$S8/sim/models/soc8_dram_model.v" "$S8/tb/soc/tb_soc8_top.sv" \
    > xvlog_sv.log 2>&1 || { grep ERROR xvlog_sv.log; exit 1; }
"$V/xelab" --timescale 1ns/1ps tb_soc8_top -s tb_fast > xelab_fast.log 2>&1 || { grep ERROR xelab_fast.log; exit 1; }
"$V/xelab" --timescale 1ns/1ps tb_soc8_top -generic_top "BAUD=115200" -generic_top "FULL=0" \
    -s tb_real > xelab_real.log 2>&1 || { grep ERROR xelab_real.log; exit 1; }
"$V/xsim" tb_fast -runall -testplusarg "PROG_DIR=$B/programs" > sim_fast.log 2>&1
"$V/xsim" tb_real -runall -testplusarg "PROG_DIR=$B/programs" > sim_real.log 2>&1

status=0
for run in fast real; do
    echo "== $run"
    grep -E "^(CASE|COVER|SOC8_TOP_|FAIL)" "sim_$run.log"
    grep -q "^SOC8_TOP_PASS" "sim_$run.log" || status=1
    if grep -q "^FAIL" "sim_$run.log"; then status=1; fi
done
echo "RESULT status=$status model=$M logs=$B"
exit $status
