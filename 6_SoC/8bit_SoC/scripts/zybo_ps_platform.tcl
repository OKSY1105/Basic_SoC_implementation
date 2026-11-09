# Zybo Z7-20 PS-only hardware platform (XSA) for the QSPI boot image.
# The FSBL that loads the SoC bitstream at power-on is built from this XSA;
# the SoC itself stays PL-only and its bitstream is not rebuilt.
# Usage: run through scripts/build_zybo_boot.sh (Vivado batch).
# Environment:
#   ZYBO_BOOT_DIR    output folder (required); the XSA is ZYBO_BOOT_DIR/zybo_ps.xsa
#   ZYBO_BOARD_REPO  folder with the Digilent board files (zybo-z7-20/A.0/board.xml)
# Steps: board part digilentinc.com:zybo-z7-20 (DDR3L, MIO, QSPI presets from
# the board files), block design with processing_system7 and the board
# preset, no PL ports used (M_AXI_GP0, FCLK_CLK0 and FCLK_RESET0 off),
# pre-synthesis fixed XSA. Prints ZYBO_PS_XSA_PASS.
foreach v {ZYBO_BOOT_DIR ZYBO_BOARD_REPO} {
    if {![info exists ::env($v)]} { error "$v is required (use scripts/build_zybo_boot.sh)" }
}
set out [file normalize $::env(ZYBO_BOOT_DIR)]
set boards [file normalize $::env(ZYBO_BOARD_REPO)]
if {![file exists [file join $boards zybo-z7-20 A.0 board.xml]]} {
    error "Zybo Z7-20 board files not found under $boards (zybo-z7-20/A.0/board.xml)"
}
set_param board.repoPaths [list $boards]
set bp [lindex [lsort [get_board_parts -quiet digilentinc.com:zybo-z7-20:part0:*]] end]
if {$bp eq ""} { error "Vivado did not load the Zybo Z7-20 board files from $boards" }

set proj [file join $out ps_proj]
file delete -force $proj
create_project ps_proj $proj -part xc7z020clg400-1 -force
set_property board_part $bp [current_project]
create_bd_design zybo_ps
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} $ps
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {0} CONFIG.PCW_EN_CLK0_PORT {0} CONFIG.PCW_EN_RST0_PORT {0}] $ps
validate_bd_design
save_bd_design
set bd [get_files zybo_ps.bd]
generate_target all $bd
add_files -norecurse [make_wrapper -files $bd -top]
set_property top zybo_ps_wrapper [current_fileset]
update_compile_order -fileset sources_1

set ddr [get_property CONFIG.PCW_UIPARAM_DDR_PARTNO $ps]
set qspi [get_property CONFIG.PCW_QSPI_PERIPHERAL_ENABLE $ps]
set uart [get_property CONFIG.PCW_UART1_PERIPHERAL_ENABLE $ps]
set xsa [file join $out zybo_ps.xsa]
write_hw_platform -fixed -force -file $xsa
if {![file exists $xsa]} { error "XSA was not written: $xsa" }
puts "ZYBO_PS_XSA_PASS board_part=$bp ddr=\"$ddr\" qspi=$qspi uart1=$uart xsa=$xsa"
