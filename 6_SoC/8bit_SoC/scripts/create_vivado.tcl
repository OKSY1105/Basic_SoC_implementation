# Usage: vivado -mode batch -source scripts/create_vivado.tcl -tclargs cpu|ram|uart PART
# Source references only; no synthesis or hardware programming is launched.
if {$argc != 2} { error "Usage: -tclargs cpu|ram|uart FPGA_PART" }
set block [lindex $argv 0]
set part [lindex $argv 1]
set root [file dirname [file dirname [file normalize [info script]]]]
set library [file normalize [file join $root .. .. 1_RTL 2_TINY_PROJECT]]
set build [file join $root build vivado_$block]
if {[file exists [file join $build unit_$block.xpr]]} { error "Project exists: $build; open it or choose another build directory" }
switch -- $block {
    cpu {
        set base [file join $library CPU 8bit_CPU]
        set src [list [file join $base RTL cpu8_alu.v] [file join $base RTL cpu8_decoder.v] [file join $base RTL cpu8_regfile.v] [file join $base RTL cpu8_top.v] [file join $base RTL cpu8_isa.vh]]
        set tb [list [file join $base TB tb_cpu8_top.sv]]
        set top cpu8_top
        set simtop tb_cpu8_top
    }
    ram {
        # Behavioral DRAM belongs to simulation sources, never synthesis sources.
        set src [list [file join $library DRAM_CONTEOLLER dram_controller.v]]
        set tb [list [file join $library DRAM dram.v] [file join $library DRAM_CONTEOLLER tb_dram_controller.v]]
        set top dram_controller
        set simtop tb_dram_controller
    }
    uart {
        set src {}
        foreach name {baud_rate_gen fifo uart_rx uart_tx uart_top} { lappend src [file join $library UART $name.v] }
        set tb [list [file join $library UART tb_uart.v]]
        set top uart_top
        set simtop tb_uart_top
    }
    default { error "Unknown block: $block" }
}
foreach name [concat $src $tb] { if {![file exists $name]} { error "Missing input: $name" } }
create_project unit_$block $build -part $part
add_files -norecurse $src
add_files -fileset sim_1 -norecurse $tb
set_property top $top [get_filesets sources_1]
set_property top $simtop [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
if {$block eq "uart"} {
    # Existing RTL omits timescale while the existing TB uses 1ns/1ps.
    set_property -dict [list xsim.elaborate.xelab.more_options {--timescale 1ns/1ps --override_timeunit --override_timeprecision}] [get_filesets sim_1]
}
if {$block eq "cpu"} {
    set_property include_dirs [list [file join $base RTL]] [get_filesets sources_1]
    set_property include_dirs [list [file join $base RTL]] [get_filesets sim_1]
}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROJECT_CREATED: [file join $build unit_$block.xpr]"
close_project
