##################################################################################
## Script Name : open_sim_gui.tcl
## Description : Opens (or creates) the CORE-5300 Vivado project, attaches the
##               6-group waveform config (tb_security_top_behav.wcfg) zoomed to
##               the full 0 ~ 3.5ms timeline, and runs all 8 simulation checks.
##################################################################################

set script_dir [file dirname [file normalize [info script]]]
set xpr_path   "$script_dir/vivado_proj/security_core5300.xpr"
set wcfg_path  "$script_dir/tb_security_top_behav.wcfg"

if {[file exists $xpr_path]} {
    open_project $xpr_path
} else {
    source "$script_dir/create_vivado_project.tcl"
}

if {[file exists $wcfg_path]} {
    add_files -fileset sim_1 -norecurse $wcfg_path
    set_property xsim.view $wcfg_path [get_filesets sim_1]
}

set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
launch_simulation

puts "=================================================================="
puts " Vivado GUI Simulation Complete! Full Waveform (0 ~ 3.5ms) Ready."
puts "=================================================================="
