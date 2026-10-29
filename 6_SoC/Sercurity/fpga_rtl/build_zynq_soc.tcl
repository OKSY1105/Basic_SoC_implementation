# Vivado 2024.2: recreate or rebuild CORE-5300 from source-only files.
# Optional -tclargs OUTPUT_DIR keeps generated files outside the source tree.
set source_dir [file dirname [file normalize [info script]]]
set output_dir [file join $source_dir build]
if {[llength $argv] > 0} { set output_dir [file normalize [lindex $argv 0]] }
file mkdir $output_dir
set project_dir [file join $output_dir zynq_soc_proj]
set project_file [file join $project_dir zynq_soc_proj.xpr]
if {[file exists $project_file]} {
    open_project $project_file
    reset_run synth_1
} else {
    create_project zynq_soc_proj $project_dir -part xc7z010clg400-1
    source [file join $source_dir zynq_sys.tcl]
    set bd_file [get_files zynq_sys.bd]
    if {[llength $bd_file] != 1} { error "Expected one zynq_sys block design" }
    generate_target all $bd_file
    add_files -norecurse [make_wrapper -files $bd_file -top]
    foreach name {clk_div.v debounce_edge.v clock_fnd_ctrl.v ultrasonic_ctrl.v security_fsm.v uart_frame_ctrl.v lcd_ctrl.v security_top.v security_top_zynq.v} {
        add_files -norecurse [file join $source_dir $name]
    }
    add_files -fileset constrs_1 -norecurse [file join $source_dir security_core5300_zynq.xdc]
    set_property top security_top_zynq [current_fileset]
}
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "Synthesis failed" }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "Implementation failed" }
set bit_file [file join [get_property DIRECTORY [get_runs impl_1]] security_top_zynq.bit]
if {![file exists $bit_file]} { error "Bitstream missing: $bit_file" }
file copy -force $bit_file [file join $output_dir security_top_zynq.bit]
write_hw_platform -fixed -include_bit -force -file [file join $output_dir security_top_zynq.xsa]
file copy -force [file join $source_dir ps7_init.tcl] [file join $output_dir ps7_init.tcl]
open_run impl_1
report_timing_summary -file [file join $output_dir timing_summary.rpt]
report_drc -file [file join $output_dir drc.rpt]
set worst_slack [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
if {$worst_slack < 0} { error "Setup timing failed: WNS=$worst_slack" }
puts "SECURITY_BUILD_PASS output=$output_dir WNS=$worst_slack"
close_project
exit 0
