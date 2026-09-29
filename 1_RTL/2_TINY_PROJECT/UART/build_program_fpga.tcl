#!/usr/bin/env -S vivado -mode batch -source

# ============================================================
# build_program_fpga.tcl
#
# Vivado에서 아래 순서로 자동 실행한다.
#
# 1. Verilog source 읽기
# 2. Synthesis
# 3. Zybo Z7 pin / clock constraint 적용
# 4. Optimization
# 5. Placement
# 6. Routing
# 7. DRC / Timing report
# 8. Bitstream 생성
# 9. Hardware Manager 연결
# 10. Zybo FPGA Programming
# 11. DONE 확인
#
# 같은 폴더에 필요한 파일:
#   fifo.v
#   baud_rate_gen.v
#   uart_tx.v
#   uart_rx.v
#   uart_top.v
#   zybo_uart_top.v
#
# 실행:
#   chmod +x build_program_fpga.tcl
#   ./build_program_fpga.tcl
#
# 현재 기본 설정:
#   Zybo Z7-20
#   XC7Z020-1CLG400C
#
# Zybo Z7-10이면 FPGA_PART만
#   xc7z010clg400-1
# 로 변경한다.
# ============================================================


# ============================================================
# 0. 기본 설정
# ============================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]

set BUILD_DIR [file join $SCRIPT_DIR "vivado_hw"]

set TOP_MODULE "zybo_uart_top"

# Zybo Z7-20
set FPGA_PART "xc7z020clg400-1"

# Zybo Z7-10이면 위 줄 대신:
# set FPGA_PART "xc7z010clg400-1"


proc fail {msg} {

    puts ""
    puts "============================================================"
    puts " ERROR"
    puts " $msg"
    puts "============================================================"
    puts ""

    exit 1
}


proc banner {msg} {

    puts ""
    puts "============================================================"
    puts " $msg"
    puts "============================================================"
    puts ""
}


# ============================================================
# 1. 기존 build 결과 삭제
# ============================================================

banner "STEP 1 : Clean old hardware build"

if {[file exists $BUILD_DIR]} {

    puts "DELETE : $BUILD_DIR"

    file delete -force $BUILD_DIR
}

file mkdir $BUILD_DIR


# ============================================================
# 2. Verilog source 확인
# ============================================================

banner "STEP 2 : Check RTL sources"

set RTL_FILES [list \
    [file join $SCRIPT_DIR "fifo.v"] \
    [file join $SCRIPT_DIR "baud_rate_gen.v"] \
    [file join $SCRIPT_DIR "uart_tx.v"] \
    [file join $SCRIPT_DIR "uart_rx.v"] \
    [file join $SCRIPT_DIR "uart_top.v"] \
    [file join $SCRIPT_DIR "zybo_uart_top.v"] \
]


foreach rtl $RTL_FILES {

    if {![file exists $rtl]} {

        fail "RTL file not found: $rtl"
    }

    puts "FOUND : $rtl"
}


# ============================================================
# 3. Verilog 읽기
#
# Vivado GUI:
# Add Sources
# ============================================================

banner "STEP 3 : Read Verilog"

foreach rtl $RTL_FILES {

    puts "READ : $rtl"

    read_verilog $rtl
}


# ============================================================
# 4. Synthesis
#
# Vivado GUI:
# Run Synthesis
#
# Verilog RTL
#     ↓
# LUT / FF / MUX / RAM 등의 netlist
# ============================================================

banner "STEP 4 : Synthesis"

if {[catch {

    synth_design \
        -top $TOP_MODULE \
        -part $FPGA_PART

} err]} {

    fail "Synthesis failed: $err"
}


puts ""
puts "SYNTHESIS COMPLETE"


# Synthesis 결과 저장
write_checkpoint \
    -force \
    [file join $BUILD_DIR "post_synth.dcp"]


report_utilization \
    -file \
    [file join $BUILD_DIR "post_synth_utilization.rpt"]


# ============================================================
# 5. Zybo Z7 Pin / Clock Constraints
#
# 별도 .xdc 파일 없이 이 TCL 안에서 직접 적용한다.
#
# zybo_uart_top.v port:
#
#   i_clk
#   i_btn_send
#   i_btn_reset
#   o_uart_txd
#   i_uart_rxd
#   o_led[3:0]
# ============================================================

banner "STEP 5 : Apply Zybo Z7 constraints"


# ------------------------------------------------------------
# 125 MHz System Clock
#
# Zybo Z7:
# K17 = 125 MHz PL clock
# ------------------------------------------------------------

set_property PACKAGE_PIN K17 \
    [get_ports i_clk]

set_property IOSTANDARD LVCMOS33 \
    [get_ports i_clk]


create_clock \
    -name sys_clk \
    -period 8.000 \
    -waveform {0.000 4.000} \
    [get_ports i_clk]


# ------------------------------------------------------------
# BTN0 = UART Send
# ------------------------------------------------------------

set_property PACKAGE_PIN K18 \
    [get_ports i_btn_send]

set_property IOSTANDARD LVCMOS33 \
    [get_ports i_btn_send]


# ------------------------------------------------------------
# BTN1 = Reset
# ------------------------------------------------------------

set_property PACKAGE_PIN P16 \
    [get_ports i_btn_reset]

set_property IOSTANDARD LVCMOS33 \
    [get_ports i_btn_reset]


# ------------------------------------------------------------
# LED0 = RX PASS
# ------------------------------------------------------------

set_property PACKAGE_PIN M14 \
    [get_ports {o_led[0]}]

set_property IOSTANDARD LVCMOS33 \
    [get_ports {o_led[0]}]


# ------------------------------------------------------------
# LED1 = TX request accepted
# ------------------------------------------------------------

set_property PACKAGE_PIN M15 \
    [get_ports {o_led[1]}]

set_property IOSTANDARD LVCMOS33 \
    [get_ports {o_led[1]}]


# ------------------------------------------------------------
# LED2 = UART ERROR
# ------------------------------------------------------------

set_property PACKAGE_PIN G14 \
    [get_ports {o_led[2]}]

set_property IOSTANDARD LVCMOS33 \
    [get_ports {o_led[2]}]


# ------------------------------------------------------------
# LED3 = Heartbeat
# ------------------------------------------------------------

set_property PACKAGE_PIN D18 \
    [get_ports {o_led[3]}]

set_property IOSTANDARD LVCMOS33 \
    [get_ports {o_led[3]}]


# ------------------------------------------------------------
# PMOD JC1
#
# Zybo TX -> NUCLEO RX
# ------------------------------------------------------------

set_property PACKAGE_PIN V15 \
    [get_ports o_uart_txd]

set_property IOSTANDARD LVCMOS33 \
    [get_ports o_uart_txd]


# ------------------------------------------------------------
# PMOD JC2
#
# Zybo RX <- NUCLEO TX
# ------------------------------------------------------------

set_property PACKAGE_PIN W15 \
    [get_ports i_uart_rxd]

set_property IOSTANDARD LVCMOS33 \
    [get_ports i_uart_rxd]


# ============================================================
# 6. Optimization
#
# Vivado Implementation의 첫 단계
# ============================================================

banner "STEP 6 : opt_design"

if {[catch {

    opt_design

} err]} {

    fail "opt_design failed: $err"
}


# ============================================================
# 7. Placement
#
# LUT / FF 등을 FPGA 내부 실제 위치에 배치
# ============================================================

banner "STEP 7 : place_design"

if {[catch {

    place_design

} err]} {

    fail "place_design failed: $err"
}


write_checkpoint \
    -force \
    [file join $BUILD_DIR "post_place.dcp"]


# ============================================================
# 8. Routing
#
# 배치된 FPGA logic들을 실제 routing resource로 연결
# ============================================================

banner "STEP 8 : route_design"

if {[catch {

    route_design

} err]} {

    fail "route_design failed: $err"
}


write_checkpoint \
    -force \
    [file join $BUILD_DIR "post_route.dcp"]


puts ""
puts "IMPLEMENTATION COMPLETE"


# ============================================================
# 9. DRC / Timing / Utilization Report
# ============================================================

banner "STEP 9 : Reports"


report_drc \
    -file \
    [file join $BUILD_DIR "drc.rpt"]


report_timing_summary \
    -file \
    [file join $BUILD_DIR "timing_summary.rpt"]


report_utilization \
    -file \
    [file join $BUILD_DIR "post_route_utilization.rpt"]


puts "Report directory:"
puts "  $BUILD_DIR"


# ============================================================
# 10. Bitstream 생성
#
# Vivado GUI:
# Generate Bitstream
# ============================================================

banner "STEP 10 : Generate Bitstream"

set BIT_FILE \
    [file join $BUILD_DIR "zybo_uart_top.bit"]


if {[catch {

    write_bitstream \
        -force \
        $BIT_FILE

} err]} {

    fail "write_bitstream failed: $err"
}


if {![file exists $BIT_FILE]} {

    fail "Bitstream file was not created: $BIT_FILE"
}


puts ""
puts "BITSTREAM CREATED"
puts "  $BIT_FILE"


# ============================================================
# 11. Hardware Manager
#
# Vivado GUI:
# Open Hardware Manager
# Open Target
# Auto Connect
# ============================================================

banner "STEP 11 : Open Hardware Manager"


if {[catch {

    open_hw_manager

} err]} {

    fail "open_hw_manager failed: $err"
}


if {[catch {

    connect_hw_server \
        -url localhost:3121

} err]} {

    fail "connect_hw_server failed: $err"
}


if {[catch {

    open_hw_target

} err]} {

    fail "open_hw_target failed. Check Zybo USB/JTAG connection: $err"
}


# ============================================================
# 12. 연결된 FPGA 찾기
# ============================================================

banner "STEP 12 : Find Zybo FPGA"


set PROGRAM_DEVICE ""


foreach dev [get_hw_devices] {

    set info [string tolower "$dev"]


    if {![catch {

        set part_name [get_property PART $dev]

    }]} {

        append info " "
        append info [string tolower $part_name]
    }


    # Z7-20
    if {$FPGA_PART eq "xc7z020clg400-1" &&
        [string match "*xc7z020*" $info]} {

        set PROGRAM_DEVICE $dev

        break
    }


    # Z7-10
    if {$FPGA_PART eq "xc7z010clg400-1" &&
        [string match "*xc7z010*" $info]} {

        set PROGRAM_DEVICE $dev

        break
    }
}


if {$PROGRAM_DEVICE eq ""} {

    puts "Detected devices: [get_hw_devices]"

    fail "Matching Zybo FPGA was not found."
}


puts "FPGA device:"
puts "  $PROGRAM_DEVICE"


# ============================================================
# 13. FPGA Programming
#
# Vivado GUI:
# Program Device
# ============================================================

banner "STEP 13 : Program FPGA"


current_hw_device \
    $PROGRAM_DEVICE


refresh_hw_device \
    -update_hw_probes false \
    $PROGRAM_DEVICE


set_property PROGRAM.FILE \
    $BIT_FILE \
    $PROGRAM_DEVICE


if {[catch {

    program_hw_devices \
        $PROGRAM_DEVICE

} err]} {

    fail "FPGA programming failed: $err"
}


refresh_hw_device \
    -update_hw_probes false \
    $PROGRAM_DEVICE


# ============================================================
# 14. DONE 확인
# ============================================================

banner "STEP 14 : Verify Programming"


set DONE_VALUE "UNKNOWN"


if {[catch {

    set DONE_VALUE \
        [get_property \
            REGISTER.IR.BIT5_DONE \
            $PROGRAM_DEVICE]

} err]} {

    puts "DONE property read warning:"
    puts "  $err"
}


puts ""
puts "============================================================"
puts " BUILD / PROGRAM RESULT"
puts "============================================================"
puts ""
puts "FPGA part : $FPGA_PART"
puts "Device    : $PROGRAM_DEVICE"
puts "Bitstream : $BIT_FILE"
puts "DONE      : $DONE_VALUE"
puts ""


if {$DONE_VALUE eq "0"} {

    fail "FPGA DONE = 0"
}


puts "FPGA PROGRAMMING COMPLETE"
puts ""
puts "Board check:"
puts ""
puts "  LED3 : heartbeat"
puts "  BTN0 : send 0x55"
puts "  LED1 : TX request"
puts "  LED0 : NUCLEO echo 0x55 received"
puts "  LED2 : UART error"
puts ""


# ============================================================
# 15. 종료
# ============================================================

catch {
    close_hw_target
}

catch {
    disconnect_hw_server
}

catch {
    close_hw_manager
}

exit 0
