#!/usr/bin/env bash
# DRAM controller TBs on both memory models (WSL/Linux, Vivado XSim).
# Usage: bash scripts/run_dram_models_tb.sh [BUILD_DIR]
#   BUILD_DIR  run folder outside the repository (default /tmp/dram_models_tb)
#   VIVADO_BIN Vivado bin folder (default /home/sean/Vivado/2024.2/bin)
# Models: dram  = behavioral 1_RTL/2_TINY_PROJECT/DRAM/dram.v (simulation)
#         bram  = board model DRAM/dram_bram_model.v (-d DRAM_BRAM_MODEL)
#         match = dram.v on the pins plus the board model beside it, compared
#                 every clock (-d DRAM_MODEL_MATCH, line-port tops only)
# Tops:   tb_dram_controller, tb_dram_controller_alt (byte port),
#         tb_dram_line, tb_dram_line_alt (line port)
# Prints each run's PASS/FAIL, LATENCY, COVER and MODEL_MATCH lines and end
# time. Exit status 0 only if all ten runs pass and no line starts with FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S8=$(dirname "$here")
R=$(cd "$S8/../.." && pwd)
L=$R/1_RTL/2_TINY_PROJECT
V=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
B=${1:-/tmp/dram_models_tb}

rm -rf "$B" && mkdir -p "$B" || exit 1
status=0
for m in dram bram match; do
    mkdir -p "$B/$m" && cd "$B/$m" || exit 1
    tops="tb_dram_controller tb_dram_controller_alt tb_dram_line tb_dram_line_alt"
    case $m in
        dram)  models="$L/DRAM/dram.v"; def="" ;;
        bram)  models="$L/DRAM/dram_bram_model.v"; def="-d DRAM_BRAM_MODEL" ;;
        match) models="$L/DRAM/dram.v $L/DRAM/dram_bram_model.v"; def="-d DRAM_MODEL_MATCH"
               tops="tb_dram_line tb_dram_line_alt" ;;
    esac
    "$V/xvlog" $def "$L/DRAM_CONTEOLLER/dram_controller.v" $models \
        "$L/DRAM_CONTEOLLER/tb_dram_controller.v" > xvlog_v.log 2>&1 || { grep ERROR xvlog_v.log; exit 1; }
    "$V/xvlog" --sv $def "$L/DRAM_CONTEOLLER/tb_dram_line.sv" > xvlog_sv.log 2>&1 || { grep ERROR xvlog_sv.log; exit 1; }
    for top in $tops; do
        "$V/xelab" "$top" -s "$top" > "xelab_$top.log" 2>&1 || { grep ERROR "xelab_$top.log"; exit 1; }
        "$V/xsim" "$top" -runall > "sim_$top.log" 2>&1
        echo "== $m $top"
        grep -E "^(DRAM_CONTROLLER_PASS|DRAM_LINE_PASS|DRAM_CONTROLLER_FAIL|DRAM_LINE_FAIL|LATENCY|COVER|MODEL_MATCH|FAIL)" "sim_$top.log"
        if [ "$m" = match ]; then grep -q "^MODEL_MATCH" "sim_$top.log" || status=1; fi
        grep -m1 '^\$finish called at time' "sim_$top.log"
        grep -qE "^(DRAM_CONTROLLER_PASS|DRAM_LINE_PASS)" "sim_$top.log" || status=1
        if grep -qE "^(FAIL|DRAM_CONTROLLER_FAIL|DRAM_LINE_FAIL)" "sim_$top.log"; then status=1; fi
    done
done
echo "RESULT status=$status logs=$B"
exit $status
