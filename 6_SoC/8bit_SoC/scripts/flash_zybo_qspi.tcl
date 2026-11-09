# Write the Zybo Z7-20 QSPI boot image (BOOT.bin) to the on-board flash over
# JTAG (Vivado Hardware Manager, batch), run by scripts/flash_zybo_qspi.sh in
# Ubuntu (WSL2) after the board's USB is attached to WSL.
# Usage: vivado -mode batch -nojournal -nolog -source flash_zybo_qspi.tcl -tclargs <BOOT.bin> <fsbl.elf>
# Flash: Spansion S25FL128S, 16 MiB, single x4 Quad-SPI (Zybo Z7 reference
# manual section 4). The FSBL initializes the PS so that Vivado's flash
# programmer can run; it also works when the board is in JTAG boot mode.
# Steps: find the one xc7z020 device (as program_zybo.tcl), select the
# S25FL128S x4-single configuration memory part, erase, program and verify.
# Prints SOC8_ZYBO_QSPI_PASS or stops with an error.
if {[llength $argv] != 2} { error "Usage: -tclargs <BOOT.bin> <fsbl.elf>" }
set boot [file normalize [lindex $argv 0]]
set fsbl [file normalize [lindex $argv 1]]
foreach f [list $boot $fsbl] { if {![file exists $f]} { error "Missing file: $f" } }

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
    error "No JTAG target: connect the Zybo PROG/UART micro-USB (J12), power the board on and attach it to WSL (scripts/wsl_usb.sh attach 0403:6010)"
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

# The flash is powered from 3.3 V (reference manual section 4), so use the
# 3.3 V single x4 entry; Vivado also lists 1.8 V and dual-flash variants.
set parts [lsort -unique [get_cfgmem_parts -quiet {s25fl128s*qspi*}]]
set part [lsearch -inline -exact $parts s25fl128s-3.3v-qspi-x4-single]
if {$part eq ""} { error "No s25fl128s-3.3v-qspi-x4-single configuration memory part in this Vivado (Zynq QSPI entries: $parts)" }
create_hw_cfgmem -hw_device $d -mem_dev $part
set cfg [get_property PROGRAM.HW_CFGMEM $d]
set_property PROGRAM.ADDRESS_RANGE {use_file} $cfg
set_property PROGRAM.FILES [list $boot] $cfg
set_property PROGRAM.ZYNQ_FSBL $fsbl $cfg
set_property PROGRAM.BLANK_CHECK 0 $cfg
set_property PROGRAM.ERASE 1 $cfg
set_property PROGRAM.CFG_PROGRAM 1 $cfg
set_property PROGRAM.VERIFY 1 $cfg
set_property PROGRAM.CHECKSUM 0 $cfg
program_hw_cfgmem -hw_cfgmem $cfg
puts "SOC8_ZYBO_QSPI_PASS target=$t device=$d part=$part boot=$boot bytes=[file size $boot] verify=1"
close_hw_target $t
disconnect_hw_server
close_hw_manager
