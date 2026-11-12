# Program the Zybo Z7-20 PL with the 8bit SoC bitstream over JTAG
# (Vivado Hardware Manager, batch), run by scripts/program_zybo.sh in Ubuntu
# (WSL2) after the board's USB is attached to WSL (scripts/wsl_usb.sh).
# Usage: vivado -mode batch -nojournal -nolog -source program_zybo.tcl -tclargs <bitstream.bit>
# Board: PROG/UART micro-USB (J12) connected, power on; boot-mode jumper JP5
# on JTAG is recommended (an SD/QSPI boot image can reconfigure the PL).
# Steps: start the local hw_server, scan every JTAG target, require exactly
# one xc7z020 device (the Zynq ARM DAP is skipped), program the bitstream,
# read the DONE status, which must read 1 (a read failure or another value
# stops with an error). Prints SOC8_ZYBO_PROGRAM_PASS or stops with an error.
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
    error "No JTAG target: connect the Zybo PROG/UART micro-USB (J12), power the board on, attach it to WSL (scripts/wsl_usb.sh attach 0403:6010) and check the Xilinx cable udev rules"
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
# Success needs a positive DONE = 1: a failed read or any other value is a failure.
if {[catch { set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $d] } msg]} {
    error "Cannot read DONE after programming $d: $msg"
}
if {$done ne "1"} { error "DONE is not 1 after programming $d (read '$done')" }
puts "SOC8_ZYBO_PROGRAM_PASS target=$t device=$d done=$done bit=$bit"
close_hw_target $t
disconnect_hw_server
close_hw_manager
