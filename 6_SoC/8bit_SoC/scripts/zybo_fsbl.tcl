# Zynq FSBL (first stage boot loader) and the PS hand-off program for the
# Zybo Z7-20 QSPI boot image, built from the PS-only XSA with the Vitis xsct
# HSI commands.
# The SoC bitstream does not instantiate the PS7 block. The FSBL is therefore
# compiled with NON_PS_INSTANTIATED_BITSTREAM, so that it does not enable the
# PL-to-PS level shifters after configuring the PL (Xilinx CR 671028).
# Without it, the undriven PL-to-PS interrupt lines raised an IRQ right after
# "FPGA Done", the FSBL locked down and fell back with a system reset, and
# the PL was cleared again (seen on 2026-11-09).
# After the PL is configured the FSBL hands off to the first PS program in
# the boot image: the Vitis hello_world template, which prints "Hello World"
# on the PS UART (J12, second channel, 115200 8N1) and then waits in a loop
# in DDR. The SoC in the PL does not use the PS.
# Usage: xsct zybo_fsbl.tcl <zybo_ps.xsa> <FSBL folder> <PS program folder>
#        (run through scripts/build_zybo_boot.sh, which sources the Vitis
#        settings so that the ARM compiler and make are on PATH)
# Output: <folder>/executable.elf for each. Prints ZYBO_FSBL_PASS.
if {[llength $argv] != 3} { error "Usage: xsct zybo_fsbl.tcl <xsa> <FSBL folder> <PS program folder>" }
lassign $argv xsa dir app_dir
set xsa [file normalize $xsa]
set dir [file normalize $dir]
set app_dir [file normalize $app_dir]
if {![file exists $xsa]} { error "Missing XSA: $xsa" }
file delete -force $dir $app_dir
set hw [hsi::open_hw_design $xsa]
hsi::generate_app -hw $hw -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -sw fsbl -dir $dir
hsi::generate_app -hw $hw -os standalone -proc ps7_cortexa9_0 -app hello_world -compile -sw ps_app -dir $app_dir
hsi::close_hw_design $hw
# Serial make: the generated Makefile builds the BSP first.
if {[catch {exec make -C $dir CFLAGS=-DNON_PS_INSTANTIATED_BITSTREAM >& [file join $dir make.log]} e]} {
    error "FSBL make failed (see [file join $dir make.log])"
}
foreach elf [list [file join $dir executable.elf] [file join $app_dir executable.elf]] {
    if {![file exists $elf]} { error "Not built: $elf" }
}
puts "ZYBO_FSBL_PASS elf=[file join $dir executable.elf] bytes=[file size [file join $dir executable.elf]] non_ps_bitstream=1 app=[file join $app_dir executable.elf] bytes=[file size [file join $app_dir executable.elf]]"
