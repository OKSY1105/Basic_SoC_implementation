#!/usr/bin/env -S vivado -mode batch -source

# ============================================================
# Zybo Z7 UART RTL Simulation Script
# Vivado / XSim
#
# 실행:
#   vivado -mode batch -source run_sim.tcl
#
# 같은 폴더에 아래 파일이 있다고 가정
#   uart_top.v
#   baud_rate_gen.v
#   uart_tx.v
#   uart_rx.v
#   fifo.v
#   tb_uart_top.v
# ============================================================


# ============================================================
# 0. Zybo Z7 종류 선택
#
# Zybo Z7-20 : xc7z020clg400-1
# Zybo Z7-10 : xc7z010clg400-1
# ============================================================

set ZYBO_VARIANT "20"

if {$ZYBO_VARIANT eq "20"} {

    set FPGA_PART "xc7z020clg400-1"

} elseif {$ZYBO_VARIANT eq "10"} {

    set FPGA_PART "xc7z010clg400-1"

} else {

    error "ZYBO_VARIANT must be 10 or 20"

}


# ============================================================
# 1. 현재 TCL 파일 위치
# ============================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]

set PROJECT_NAME "uart_zybo_z7_sim"

set PROJECT_DIR [file join $SCRIPT_DIR "vivado_sim"]


# ============================================================
# 2. Vivado Project 생성
# ============================================================

create_project $PROJECT_NAME $PROJECT_DIR \
    -part $FPGA_PART \
    -force


# ============================================================
# 3. RTL Source 추가
# ============================================================

add_files [file join $SCRIPT_DIR "fifo.v"]

add_files [file join $SCRIPT_DIR "baud_rate_gen.v"]

add_files [file join $SCRIPT_DIR "uart_tx.v"]

add_files [file join $SCRIPT_DIR "uart_rx.v"]

add_files [file join $SCRIPT_DIR "uart_top.v"]


# RTL top module
set_property top uart_top [get_filesets sources_1]


# Compile 순서 정리
update_compile_order -fileset sources_1


# ============================================================
# 4. Testbench 추가
# ============================================================

add_files -fileset sim_1 \
    [file join $SCRIPT_DIR "tb_uart.v"]


# Simulation top
set_property top tb_uart_top [get_filesets sim_1]


update_compile_order -fileset sim_1


# ============================================================
# 5. Simulation 실행
# ============================================================

launch_simulation \
    -simset sim_1 \
    -mode behavioral


# ============================================================
# 6. Waveform 기록
# ============================================================

# Testbench 전체
log_wave -r /tb_uart_top/*


# UART TOP 내부
log_wave -r /tb_uart_top/u_uart_top/*


# TX 내부
log_wave -r /tb_uart_top/u_uart_top/u_uart_tx/*


# RX 내부
log_wave -r /tb_uart_top/u_uart_top/u_uart_rx/*


# ============================================================
# 7. 중요 신호 Wave 창에 추가
# ============================================================

# Clock / Reset
add_wave /tb_uart_top/i_clk

add_wave /tb_uart_top/i_rst_n


# ============================================================
# CPU -> UART TX
# ============================================================

add_wave /tb_uart_top/i_thr_we

add_wave /tb_uart_top/i_thr_wdata


# ============================================================
# UART serial TX / RX
# ============================================================

add_wave /tb_uart_top/o_uart_txd

add_wave /tb_uart_top/i_uart_rxd


# ============================================================
# UART RX -> CPU
# ============================================================

add_wave /tb_uart_top/o_lsr_dr

add_wave /tb_uart_top/i_rhr_re

add_wave /tb_uart_top/o_rhr_rdata


# ============================================================
# Line Status
# ============================================================

add_wave /tb_uart_top/o_lsr_thre

add_wave /tb_uart_top/o_lsr_temt

add_wave /tb_uart_top/o_lsr_fe

add_wave /tb_uart_top/o_lsr_pe

add_wave /tb_uart_top/o_lsr_oe


# ============================================================
# FIFO 상태
# ============================================================

add_wave /tb_uart_top/o_tx_fifo_full

add_wave /tb_uart_top/o_rx_fifo_full


# ============================================================
# Testbench 결과
# ============================================================

add_wave /tb_uart_top/tb_expected_data

add_wave /tb_uart_top/tb_received_data

add_wave /tb_uart_top/tb_error

add_wave /tb_uart_top/tb_done


# ============================================================
# TX 내부 신호
# ============================================================

add_wave /tb_uart_top/u_uart_top/u_uart_tx/r_state

add_wave /tb_uart_top/u_uart_top/u_uart_tx/r_bit_cnt

add_wave /tb_uart_top/u_uart_top/u_uart_tx/r_tx_shift

add_wave /tb_uart_top/u_uart_top/u_uart_tx/r_fifo_rd_en

add_wave /tb_uart_top/u_uart_top/u_uart_tx/w_fifo_empty


# ============================================================
# RX 내부 신호
# ============================================================

add_wave /tb_uart_top/u_uart_top/u_uart_rx/state

add_wave /tb_uart_top/u_uart_top/u_uart_rx/r_os_cnt

add_wave /tb_uart_top/u_uart_top/u_uart_rx/r_bit_cnt

add_wave /tb_uart_top/u_uart_top/u_uart_rx/r_rx_shift

add_wave /tb_uart_top/u_uart_top/u_uart_rx/r_rxd_ff1

add_wave /tb_uart_top/u_uart_top/u_uart_rx/r_rxd_ff2

add_wave /tb_uart_top/u_uart_top/u_uart_rx/r_fifo_w_en


# ============================================================
# Baud Generator
# ============================================================

add_wave /tb_uart_top/u_uart_top/w_baud_tick

add_wave /tb_uart_top/u_uart_top/w_os_tick


# ============================================================
# 8. Simulation Run
# ============================================================

run 1 ms


# ============================================================
# 9. Wave configuration 저장
# ============================================================

set WCFG_FILE \
    [file join $PROJECT_DIR "uart_wave.wcfg"]

catch {

    save_wave_config $WCFG_FILE

}


# ============================================================
# 10. 종료
# ============================================================

close_sim

close_project
