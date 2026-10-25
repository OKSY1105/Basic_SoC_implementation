set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root BUILD synth]
if {[info exists ::env(CPU8_SYNTH_BUILD)]} {set out $::env(CPU8_SYNTH_BUILD)}
file mkdir $out
set part xc7z020clg400-1
if {[info exists ::env(CPU8_FPGA_PART)]} {set part $::env(CPU8_FPGA_PART)}
read_verilog -sv -include_dirs [file join $root RTL] [lsort [glob [file join $root RTL *.v]]]
synth_design -top cpu8_top -part $part -mode out_of_context
set latches [get_cells -hierarchical -filter {REF_NAME == LDCE || REF_NAME == LDPE}]
if {[llength $latches] != 0} {error "Unexpected latch primitives: $latches"}
report_utilization -file [file join $out utilization.rpt]
write_checkpoint -force [file join $out cpu8_synth.dcp]
set fd [open [file join $out status.txt] w]
puts $fd "PASS: cpu8_top out-of-context synthesis; part=$part; latch_count=0"
puts $fd "No placement/routing, pin constraints or final-board timing claim."
close $fd
puts "CPU8_SYNTH_PASS part=$part latch_count=0"
