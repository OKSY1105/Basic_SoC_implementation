# Out-of-context synthesis of soc8_top (no board pins, MMCM or memory model).
# Usage: vivado -mode batch -nojournal -source scripts/synth_soc8_top.tcl
# Environment (optional):
#   SOC8_SYNTH_BUILD  output folder (default build/synth_soc8_top)
#   SOC8_FPGA_PART    part (default xc7z020clg400-1, Zybo Z7-20)
#   SOC8_ROM_FILE     ROM image; without it a filled pseudo-random image is
#                     written to the output folder, because an empty ROM lets
#                     synthesis remove most of the CPU as constant logic.
# Checks: no latch primitives, no combinational loop (DRC LUTLP-1).
# Reports: utilization, setup WNS with a 10 ns (100 MHz) clock on i_clk.
# Synthesis estimate only: no placement/routing or board timing claim.
set root [file normalize [file join [file dirname [info script]] ..]]
set library [file normalize [file join $root .. .. 1_RTL 2_TINY_PROJECT]]
set out [file join $root build synth_soc8_top]
if {[info exists ::env(SOC8_SYNTH_BUILD)]} {set out $::env(SOC8_SYNTH_BUILD)}
file mkdir $out
set part xc7z020clg400-1
if {[info exists ::env(SOC8_FPGA_PART)]} {set part $::env(SOC8_FPGA_PART)}

if {[info exists ::env(SOC8_ROM_FILE)]} {
    set rom [file normalize $::env(SOC8_ROM_FILE)]
} else {
    set rom [file join $out rom_filled.mem]
    set fd [open $rom w]
    set x 12345
    for {set i 0} {$i < 4096} {incr i} {
        set x [expr {(1103515245 * $x + 12345) & 0x7fffffff}]
        puts $fd [format %04x [expr {($x >> 8) & 0xffff}]]
    }
    close $fd
}

set cpu [file join $library CPU 8bit_CPU RTL]
set src [list \
    [file join $cpu cpu8_alu.v] [file join $cpu cpu8_decoder.v] \
    [file join $cpu cpu8_regfile.v] [file join $cpu cpu8_top.v] \
    [file join $library BUS reset_sync.v] [file join $library BUS ahb_apb_bridge.v] \
    [file join $library Cache cache.v] \
    [file join $library DRAM_CONTEOLLER dram_controller.v] \
    [file join $library UART baud_rate_gen.v] [file join $library UART fifo.v] \
    [file join $library UART uart_rx.v] [file join $library UART uart_tx.v] \
    [file join $library UART uart_top.v] \
    [file join $root rtl bus soc8_ahb_bus.v] [file join $root rtl rom soc8_rom.v] \
    [file join $root rtl uart soc8_uart_apb.v] [file join $root rtl soc soc8_top.v]]
foreach name $src { if {![file exists $name]} { error "Missing input: $name" } }
read_verilog -sv $src
synth_design -top soc8_top -part $part -mode out_of_context -include_dirs $cpu \
    -generic "ROM_FILE=\"$rom\""

set latches [get_cells -hierarchical -filter {REF_NAME == LDCE || REF_NAME == LDPE}]
if {[llength $latches] != 0} {error "Unexpected latch primitives: $latches"}
report_drc -name soc8_loops -checks {LUTLP-1} -file [file join $out drc_loops.rpt]
set loops [llength [get_drc_violations -quiet -name soc8_loops]]
if {$loops != 0} {error "Combinational loops: $loops (see drc_loops.rpt)"}

create_clock -name i_clk -period 10.000 [get_ports i_clk]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -file [file join $out timing_summary.rpt]
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
# Counts as printed in the utilization report ("Used" column).
set util [report_utilization -return_string]
proc used {util name} {
    if {[regexp "\\|\\s*$name\\*?\\s*\\|\\s*(\\d+)" $util -> n]} {return $n}
    return "?"
}
set luts [used $util "Slice LUTs"]
set ffs [used $util "Slice Registers"]
set brams [used $util "Block RAM Tile"]
set lutrams [used $util "LUT as Memory"]
write_checkpoint -force [file join $out soc8_top_synth.dcp]
set result "SOC8_SYNTH_PASS part=$part lut=$luts ff=$ffs bram=$brams lutram=$lutrams latch=0 loops=0 wns_100mhz=$wns"
set fd [open [file join $out status.txt] w]
puts $fd $result
puts $fd "ROM image: $rom"
puts $fd "Synthesis estimate only; no placement/routing, pin constraints or board timing claim."
close $fd
puts $result
