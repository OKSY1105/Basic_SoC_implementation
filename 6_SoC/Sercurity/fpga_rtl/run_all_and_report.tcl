set script_dir [file dirname [file normalize [info script]]]

puts "=================================================================="
puts " STEP 1: RUNNING VIVADO BEHAVIORAL SIMULATION (tb_security_top)..."
puts "=================================================================="
open_project [file join $script_dir vivado_proj security_core5300.xpr]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
run all
close_sim
close_project

puts "=================================================================="
puts " STEP 2: RUNNING VIVADO SYNTHESIS, IMPLEMENTATION & BITSTREAM..."
puts "=================================================================="
source [file join $script_dir build_zynq_soc.tcl]
