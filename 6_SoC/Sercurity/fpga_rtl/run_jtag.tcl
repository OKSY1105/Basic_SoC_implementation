# ==============================================================================
# JTAG One-Click Run Script for CORE-5300 Zynq SoC
# ==============================================================================

# Automatically resolve the script's directory and switch to it
set script_dir [file dirname [file normalize [info script]]]
cd $script_dir

set build_dir [file join $script_dir build]
if {[llength $argv] > 0} {set build_dir [file normalize [lindex $argv 0]]}
foreach name {ps7_init.tcl security_top_zynq.bit uart_bridge.elf} {
    if {![file exists [file join $build_dir $name]]} {
        error "Missing $name. Build hardware and run compile_arm.bat first."
    }
}

connect

# Select ARM Cortex-A9 Core 0
targets -set -nocase -filter {name =~ "*A9*#0"}

# Reset System
rst -system
after 1000

# Initialize PS7 clocks, DDR, and MIO/EMIO
targets -set -nocase -filter {name =~ "*A9*#0"}
source [file join $build_dir "ps7_init.tcl"]
ps7_init

# Program FPGA PL Fabric with Security Top Zynq Bitstream
puts "=== Programming FPGA Bitstream (security_top_zynq.bit) ==="
fpga [file join $build_dir "security_top_zynq.bit"]
after 500

# Enable PS-PL level shifters and release PL resets AFTER FPGA bitstream
targets -set -nocase -filter {name =~ "*A9*#0"}
ps7_post_config

# Download and Run ARM UART Bridge Firmware (9600 bps)
puts "=== Downloading ARM UART Bridge Firmware (uart_bridge.elf) ==="
targets -set -nocase -filter {name =~ "*A9*#0"}
dow [file join $build_dir "uart_bridge.elf"]
bpremove -all
con
after 500
puts "=== Target 0 State: [state] (PC: [rrd pc]) ==="
puts "=== SUCCESS: CORE-5300 Smart Security System is NOW RUNNING! ==="
exit 0
