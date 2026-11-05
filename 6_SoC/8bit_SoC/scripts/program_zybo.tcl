# Program the Zybo Z7-20 PL with the 8bit SoC bitstream over JTAG
# (Vivado Hardware Manager, batch). WSL has no USB access, so this runs with
# the Windows Vivado through scripts/program_zybo.ps1.
# Usage: vivado -mode batch -nojournal -nolog -source program_zybo.tcl -tclargs <bitstream.bit>
# Board: PROG/UART micro-USB (J12) connected, power on; boot-mode jumper JP5
# on JTAG is recommended (an SD/QSPI boot image can reconfigure the PL).
# Steps: start the local hw_server, scan every JTAG target, require exactly
# one xc7z020 device (the Zynq ARM DAP is skipped), program the bitstream,
# read the DONE status. Prints SOC8_ZYBO_PROGRAM_PASS or stops with an error.
if {[llength $argv] != 1} { error "Usage: -tclargs <bitstream.bit>" }
set bit [file normalize [lindex $argv 0]]
if {![file exists $bit]} { error "Missing bitstream: $bit" }

proc zynq_devices {} {
    set found {}
    foreach d [get_hw_devices -quiet] {
        if {[string match -nocase xc7z020* [get_property PART $d]]} { lappend found $d }
    }
    return $found
}

open_hw_manager
connect_hw_server
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    error "No JTAG target: connect the Zybo PROG/UART micro-USB (J12), power the board on, and check the Digilent cable driver"
}
set hits {}
foreach t $targets {
    open_hw_target $t
    foreach d [zynq_devices] { lappend hits [list $t $d] }
    close_hw_target $t
}
puts "SOC8_ZYBO_SCAN targets=[llength $targets] xc7z020_devices=[llength $hits]"
if {[llength $hits] != 1} { error "Expected one xc7z020 device on the JTAG targets, found [llength $hits]: $hits" }

set t [lindex $hits 0 0]
open_hw_target $t
set d [lindex [zynq_devices] 0]
current_hw_device $d
refresh_hw_device -update_hw_probes false $d
set_property PROBES.FILE {} $d
set_property FULL_PROBES.FILE {} $d
set_property PROGRAM.FILE $bit $d
program_hw_devices $d
refresh_hw_device -update_hw_probes false $d
set done unknown
catch { set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $d] }
if {$done eq "0"} { error "DONE is low after programming $d" }
puts "SOC8_ZYBO_PROGRAM_PASS target=$t device=$d done=$done bit=$bit"
close_hw_target $t
disconnect_hw_server
close_hw_manager
