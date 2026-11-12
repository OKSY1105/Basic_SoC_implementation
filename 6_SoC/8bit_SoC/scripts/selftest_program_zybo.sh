#!/usr/bin/env bash
# Self-test of the success rules of program_zybo.tcl / program_zybo.sh,
# without a board, USB or Vivado:
#  1. program_zybo.tcl runs in tclsh with the Hardware Manager commands
#     replaced by stubs; only DONE = 1 may print SOC8_ZYBO_PROGRAM_PASS
#     (DONE 0, an empty value and a failed read must stop with an error).
#  2. program_zybo.sh runs from a copy next to a stub wsl_usb.sh, with a
#     stub vivado that prints a chosen log; status 0 only with Vivado exit 0,
#     "End of startup status: HIGH" and SOC8_ZYBO_PROGRAM_PASS ... done=1.
# Usage: bash scripts/selftest_program_zybo.sh
# Prints one PROGRAM_SELFTEST line per case and PROGRAM_SELFTEST_PASS / _FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
command -v tclsh > /dev/null || { echo "PROGRAM_SELFTEST_FAIL tclsh not found"; exit 1; }
W=$(mktemp -d /tmp/program_selftest.XXXXXX) || exit 1
trap 'rm -rf "$W"' EXIT
bad=0
check() {   # name want got detail
    if [ "$2" = "$3" ]; then r=ok; else r=WRONG; bad=$((bad + 1)); fi
    echo "PROGRAM_SELFTEST $1 $r expected=$2 got=$3 | $4"
}

# ---- 1. Tcl: DONE rule -------------------------------------------------------
touch "$W/test.bit"
cat > "$W/stub.tcl" << 'EOF'
set case [lindex $argv 0]
set script [lindex $argv 2]
proc open_hw_manager {} {}
proc connect_hw_server {} {}
proc disconnect_hw_server {} {}
proc close_hw_manager {} {}
proc get_hw_targets {args} { return {localhost:3121/xilinx_tcf/Digilent/STUB} }
proc open_hw_target {t} {}
proc close_hw_target {t} {}
proc get_hw_devices {args} { return {arm_dap_0 xc7z020_1} }
proc current_hw_device {d} {}
proc refresh_hw_device {args} {}
proc set_property {args} {}
proc program_hw_devices {d} {}
proc get_property {name obj} {
    if {$name eq "PART"} { if {$obj eq "xc7z020_1"} { return xc7z020clg400-1 } ; return arm_dap }
    if {$name eq "REGISTER.CONFIG_STATUS.BIT14_DONE_PIN"} {
        switch $::case {
            done1   { return 1 }
            done0   { return 0 }
            empty   { return "" }
            readerr { error "property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN not found" }
        }
    }
    error "unexpected get_property $name $obj"
}
set argv [list [lindex $argv 1]]
set argc 1
source $script
EOF
for c in done1:pass done0:error empty:error readerr:error; do
    name=${c%%:*}; want=${c##*:}
    out=$(tclsh "$W/stub.tcl" "$name" "$W/test.bit" "$here/program_zybo.tcl" 2>&1); code=$?
    got=error
    [ $code -eq 0 ] && echo "$out" | grep -q '^SOC8_ZYBO_PROGRAM_PASS' && got=pass
    [ $got = pass ] && [ $name = done1 ] && ! echo "$out" | grep -q ' done=1 ' && got=pass_without_done1
    check "tcl_done_$name" "$want" "$got" "exit=$code $(echo "$out" | grep -E 'SOC8_ZYBO_PROGRAM_PASS|DONE' | head -1)"
done

# ---- 2. shell: log rule ------------------------------------------------------
mkdir -p "$W/scripts" "$W/bin"
cp "$here/program_zybo.sh" "$W/scripts/"
touch "$W/scripts/program_zybo.tcl"
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/scripts/wsl_usb.sh"
cat > "$W/bin/vivado" << 'EOF'
#!/usr/bin/env bash
cat "$STUB_LOG"
exit "$STUB_CODE"
EOF
chmod +x "$W/bin/vivado"
HIGH='INFO: [Labtools 27-3164] End of startup status: HIGH'
PASS='SOC8_ZYBO_PROGRAM_PASS target=localhost:3121/xilinx_tcf/Digilent/STUB device=xc7z020_1 done=1 bit=/x.bit'
run_sh() {   # name want code log-lines...
    name=$1; want=$2; code=$3; shift 3
    printf '%s\n' "$@" > "$W/log_$name"
    out=$(STUB_LOG="$W/log_$name" STUB_CODE=$code VIVADO_BIN="$W/bin" bash "$W/scripts/program_zybo.sh" "$W/test.bit" 2>&1)
    st=$(echo "$out" | sed -n 's/^RESULT status=\([0-9]*\).*/\1/p')
    log=$(echo "$out" | sed -n 's/^RESULT status=[0-9]* log=\(\/tmp\/zybo_program\.[A-Za-z0-9]*\)\/program\.log$/\1/p')
    [ -n "$log" ] && rm -rf "$log"
    check "sh_$name" "$want" "${st:-none}" "$(echo "$out" | grep -E '^FAIL' | head -1)"
}
run_sh good          0 0 "$HIGH" "$PASS"
run_sh no_startup    1 0 "$PASS"
run_sh startup_low   1 0 'INFO: [Labtools 27-3164] End of startup status: LOW' "$PASS"
run_sh vivado_exit1  1 1 "$HIGH" "$PASS"
run_sh done_unknown  1 0 "$HIGH" "${PASS/done=1/done=unknown}"
run_sh no_pass       1 0 "$HIGH"

[ $bad -eq 0 ] && echo "PROGRAM_SELFTEST_PASS cases=10" || echo "PROGRAM_SELFTEST_FAIL wrong=$bad"
exit $((bad != 0))
