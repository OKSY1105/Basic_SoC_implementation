# Source from an already-open Vivado project's Tcl Console.
set source_dir [file dirname [file normalize [info script]]]
foreach name {clk_div.v debounce_edge.v clock_fnd_ctrl.v ultrasonic_ctrl.v security_fsm.v uart_frame_ctrl.v lcd_ctrl.v security_top.v} {
    set source_file [file join $source_dir $name]
    if {[llength [get_files -quiet $source_file]] == 0} { add_files -norecurse $source_file }
}
set_property top security_top [current_fileset]
set_property top tb_security_top [get_filesets sim_1]
set stream_tb [file join $source_dir tb_distance_stream.sv]
if {[llength [get_files -quiet $stream_tb]] == 0} {add_files -fileset sim_1 -norecurse $stream_tb}
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "SIMULATION_SOURCES_READY: lcd_ctrl.v is included. Run Behavioral Simulation."
