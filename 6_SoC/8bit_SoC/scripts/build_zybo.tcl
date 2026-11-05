# Zybo Z7-20 board build of soc8_zybo_top: synthesis, placement, routing,
# reports and bitstream (non-project batch flow).
# Usage: run through scripts/build_zybo.sh, which assembles the firmware.
# Environment:
#   SOC8_BUILD      output folder (required)
#   SOC8_ROM_FILE   ROM image (required, absolute path of calc.mem)
#   SOC8_FPGA_PART  part (default xc7z020clg400-1, Zybo Z7-20)
# Checks: no latch primitives, no combinational loop (DRC LUTLP-1), the
# DRAM model array is block RAM, setup and hold timing met after routing,
# no unconstrained I/O (DRC NSTD-1/UCIO-1 stop write_bitstream).
# Reports in SOC8_BUILD: utilization, timing summary, power (vectorless
# estimate), clock utilization, DRC, I/O. Prints SOC8_ZYBO_BUILD_PASS.
set root [file normalize [file join [file dirname [info script]] ..]]
set library [file normalize [file join $root .. .. 1_RTL 2_TINY_PROJECT]]
if {![info exists ::env(SOC8_BUILD)] || ![info exists ::env(SOC8_ROM_FILE)]} {
    error "SOC8_BUILD and SOC8_ROM_FILE are required (use scripts/build_zybo.sh)"
}
set out [file normalize $::env(SOC8_BUILD)]
set rom [file normalize $::env(SOC8_ROM_FILE)]
if {![file exists $rom]} { error "Missing ROM image: $rom" }
set part xc7z020clg400-1
if {[info exists ::env(SOC8_FPGA_PART)]} {set part $::env(SOC8_FPGA_PART)}
file mkdir $out

set cpu [file join $library CPU 8bit_CPU RTL]
set src [list \
    [file join $cpu cpu8_alu.v] [file join $cpu cpu8_decoder.v] \
    [file join $cpu cpu8_regfile.v] [file join $cpu cpu8_top.v] \
    [file join $library BUS reset_sync.v] [file join $library BUS ahb_apb_bridge.v] \
    [file join $library Cache cache.v] \
    [file join $library DRAM_CONTEOLLER dram_controller.v] \
    [file join $library DRAM dram_bram_model.v] \
    [file join $library UART baud_rate_gen.v] [file join $library UART fifo.v] \
    [file join $library UART uart_rx.v] [file join $library UART uart_tx.v] \
    [file join $library UART uart_top.v] \
    [file join $root rtl bus soc8_ahb_bus.v] [file join $root rtl rom soc8_rom.v] \
    [file join $root rtl uart soc8_uart_apb.v] [file join $root rtl soc soc8_top.v] \
    [file join $root fpga boards zybo soc8_zybo_top.v]]
set xdc [file join $root fpga constraints soc8_zybo_z7_20.xdc]
foreach name [concat $src [list $xdc]] { if {![file exists $name]} { error "Missing input: $name" } }

read_verilog -sv $src
read_xdc $xdc
synth_design -top soc8_zybo_top -part $part -include_dirs $cpu -generic "ROM_FILE=\"$rom\""

set latches [get_cells -hierarchical -filter {REF_NAME == LDCE || REF_NAME == LDPE}]
if {[llength $latches] != 0} {error "Unexpected latch primitives: $latches"}
report_drc -name zybo_loops -checks {LUTLP-1} -file [file join $out drc_loops.rpt]
if {[llength [get_drc_violations -quiet -name zybo_loops]] != 0} {error "Combinational loops (see drc_loops.rpt)"}
set rams [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.bram.* && NAME =~ u_dram/*}]
if {[llength $rams] == 0} {error "The DRAM model array is not block RAM"}
report_utilization -file [file join $out utilization_synth.rpt]

opt_design
place_design
phys_opt_design
route_design

report_utilization -file [file join $out utilization.rpt]
report_utilization -hierarchical -file [file join $out utilization_hier.rpt]
report_timing_summary -max_paths 10 -file [file join $out timing_summary.rpt]
report_clock_utilization -file [file join $out clock_utilization.rpt]
report_power -file [file join $out power.rpt]
report_drc -file [file join $out drc.rpt]
report_io -file [file join $out io.rpt]

set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
set whs [get_property SLACK [get_timing_paths -hold -max_paths 1 -nworst 1]]
if {$wns < 0 || $whs < 0} {error "Timing not met after routing: WNS=$wns WHS=$whs (see timing_summary.rpt)"}

proc used {util name} {
    if {[regexp "\\|\\s*$name\\*?\\s*\\|\\s*(\\d+(\\.\\d+)?)" $util -> n]} {return $n}
    return "?"
}
set util [report_utilization -return_string]
set pwr [report_power -return_string]
proc watts {pwr name} {
    if {[regexp "\\|\\s*$name\\s*\\|\\s*(\[0-9.\]+)" $pwr -> w]} {return $w}
    return "?"
}
set bit [file join $out soc8_zybo_top.bit]
write_checkpoint -force [file join $out soc8_zybo_top_routed.dcp]
write_bitstream -force $bit

set result [format "SOC8_ZYBO_BUILD_PASS part=%s lut=%s ff=%s bram=%s lutram=%s bufg=%s mmcm=%s wns_ns=%s whs_ns=%s power_total_w=%s power_dynamic_w=%s power_static_w=%s" \
    $part [used $util "Slice LUTs"] [used $util "Slice Registers"] [used $util "Block RAM Tile"] \
    [used $util "LUT as Memory"] [used $util "BUFGCTRL"] [used $util "MMCME2_ADV"] $wns $whs \
    [watts $pwr "Total On-Chip Power \\(W\\)"] [watts $pwr "Dynamic \\(W\\)"] [watts $pwr "Device Static \\(W\\)"]]
set fd [open [file join $out status.txt] w]
puts $fd $result
puts $fd "bitstream: $bit"
puts $fd "ROM image: $rom"
puts $fd "Power is Vivado's vectorless estimate (default activity), not a board measurement."
close $fd
puts $result
puts "SOC8_ZYBO_BITSTREAM $bit"
