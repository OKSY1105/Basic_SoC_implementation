# XSCT 2024.2: regenerate the FSBL from the current hardware platform.
set source_dir [file dirname [file normalize [info script]]]
set output_dir [file join $source_dir build]
if {[llength $argv] > 0} {set output_dir [file normalize [lindex $argv 0]]}
set xsa [file join $output_dir security_top_zynq.xsa]
if {![file exists $xsa]} {error "Run build_zynq_soc.tcl first: $xsa is missing"}
set workspace [file join $output_dir fsbl_workspace]
setws $workspace
if {[file exists [file join $workspace zynq_fsbl_plat platform.spr]]} {
    platform read [file join $workspace zynq_fsbl_plat platform.spr]
    platform active zynq_fsbl_plat
} else {
    platform create -name zynq_fsbl_plat -hw $xsa -proc ps7_cortexa9_0 -os standalone
}
platform write
platform generate
set fsbl [file join $workspace zynq_fsbl_plat export zynq_fsbl_plat sw zynq_fsbl_plat boot fsbl.elf]
if {![file exists $fsbl]} {error "FSBL generation did not produce $fsbl"}
file copy -force $fsbl [file join $output_dir fsbl.elf]
puts "FSBL_BUILD_PASS: [file join $output_dir fsbl.elf]"
exit
