##################################################################################
## Script Name : create_vivado_project.tcl
## Target Part : xc7z010clg400-1 (CORE-5300 Zynq-7000 Training Kit)
## Usage       : In Vivado Tcl Console:
##               cd C:/Antigravity_project/Sercurity/fpga_rtl
##               source create_vivado_project.tcl
##################################################################################

set proj_name "security_core5300"
set script_dir [file dirname [file normalize [info script]]]
set proj_dir   "$script_dir/vivado_proj"

create_project -force $proj_name $proj_dir -part xc7z010clg400-1

add_files -norecurse [list \
    "$script_dir/clk_div.v" \
    "$script_dir/debounce_edge.v" \
    "$script_dir/clock_fnd_ctrl.v" \
    "$script_dir/ultrasonic_ctrl.v" \
    "$script_dir/security_fsm.v" \
    "$script_dir/uart_frame_ctrl.v" \
    "$script_dir/lcd_ctrl.v" \
    "$script_dir/security_top.v" \
]

add_files -fileset constrs_1 -norecurse "$script_dir/security_core5300.xdc"
add_files -fileset sim_1     -norecurse [list \
    "$script_dir/tb_security_top.v" \
    "$script_dir/tb_post_synth.v" \
    "$script_dir/tb_distance_stream.sv" \
    "$script_dir/tb_uart_link.sv" \
]

set_property top security_top    [current_fileset]
set_property top tb_security_top [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=================================================================="
puts " Vivado project '$proj_name' (xc7z010clg400-1) created successfully!"
puts " Location: $proj_dir"
puts "=================================================================="
