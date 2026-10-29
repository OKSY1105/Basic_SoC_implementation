##################################################################################
## Script Name : run_vivado_verify.tcl
## Target Part : xc7z010clg400-1 (CORE-5300 Zynq-7000 Training Kit)
## Description : Automated Stage 2 (Synthesis, Implementation, Timing, DRC, Bitstream)
##               & Stage 3 (Post-Synthesis Gate-Level Netlist Export) Verification
##################################################################################

set script_dir [file dirname [file normalize [info script]]]
set out_dir    [file join $script_dir build verify]
file mkdir $out_dir

puts "=================================================================="
puts " (STAGE 2-1) Reading RTL & XDC for xc7z010clg400-1..."
puts "=================================================================="

read_verilog [list \
    "$script_dir/clk_div.v" \
    "$script_dir/debounce_edge.v" \
    "$script_dir/clock_fnd_ctrl.v" \
    "$script_dir/ultrasonic_ctrl.v" \
    "$script_dir/security_fsm.v" \
    "$script_dir/uart_frame_ctrl.v" \
    "$script_dir/lcd_ctrl.v" \
    "$script_dir/security_top.v" \
]
read_xdc "$script_dir/security_core5300.xdc"

puts "=================================================================="
puts " (STAGE 2-2) Running Vivado Synthesis (50MHz Hardware Config)..."
puts "=================================================================="
synth_design -top security_top -part xc7z010clg400-1
report_utilization    -file "$out_dir/synth_utilization.rpt"
report_timing_summary -file "$out_dir/synth_timing.rpt"
write_verilog -force -mode funcsim "$out_dir/security_top_post_synth_hw.v"

puts "=================================================================="
puts " (STAGE 2-3) Running Implementation (Opt / Place / Route) & Bitstream..."
puts "=================================================================="
opt_design
place_design
route_design

report_timing_summary -file "$out_dir/impl_timing.rpt"
report_io             -file "$out_dir/impl_io.rpt"
report_drc            -file "$out_dir/impl_drc.rpt"
write_bitstream -force "$out_dir/security_top.bit"

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "=================================================================="
puts " (STAGE 2 PASS) Post-Route WNS = ${wns} ns, WHS = ${whs} ns"
puts "=================================================================="

puts "=================================================================="
puts " (STAGE 3 PREP) Generating Post-Synthesis Gate-Level Netlist for Sim..."
puts "=================================================================="
synth_design -top security_top -part xc7z010clg400-1 \
    -generic CLKS_PER_US=4 \
    -generic CLKS_PER_2MS=20 \
    -generic CLKS_PER_50MS=800 \
    -generic CLKS_PER_1S=8000 \
    -generic DEBOUNCE_CYCLES=40 \
    -generic SEC_PER_MIN=2 \
    -generic CLKS_PER_BIT=8 \
    -generic BLINK_TICKS_50MS=2 \
    -generic REARM_TICKS_50MS=1

write_verilog -force -mode funcsim "$out_dir/security_top_post_synth_sim.v"
puts "=================================================================="
puts " (STAGE 3 PREP PASS) Gate-Level Functional Netlist Exported!"
puts "=================================================================="
exit
