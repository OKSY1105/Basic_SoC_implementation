#!/usr/bin/env tclsh

set root [file normalize [file dirname [info script]]]
cd $root

# ---- 설정 ----
set USE_GUI       1      ;# 1이면 XSim GUI를 띄움 (창을 닫아야 종료됨)
set clk_period_ns 10     ;# tb_cpu_top.v의 클럭 주기에 맞게 수정
set max_cycles    100000 ;# 안전장치 (실제 종료는 $finish 시각 기준)

# Vivado simulation tools
foreach tool {xvlog xelab xsim} {
    if {[auto_execok $tool] eq ""} {
        error "$tool not found. Source Vivado settings64.sh first."
    }
}

# 1. Clean previous simulation
source [file join $root clean.tcl]

# 2. Collect CPU RTL and Testbench
set files [concat \
    [list [file join $root CPU cpu_top.v]] \
    [lsort [glob -nocomplain [file join $root CPU CU *.v]]] \
    [lsort [glob -nocomplain [file join $root CPU DU *.v]]] \
    [list [file join $root TB tb_cpu_top.v]]]

foreach f $files {
    if {![file isfile $f]} {
        error "Source not found: $f"
    }
}

# 3. Compile
puts "STEP 1: Compile"
exec xvlog -sv {*}$files >@stdout 2>@stderr

# 4. Elaborate
puts "STEP 2: Elaborate"
exec xelab tb_cpu_top -debug all \
    -s cpu_mips8_sim >@stdout 2>@stderr

# 5. Generate XSim Tcl script
set setup [file join $root .xsim_gui_setup.tcl]
set fd [open $setup w]

puts $fd "set clk_period_ns $clk_period_ns"
puts $fd "set max_cycles $max_cycles"
puts $fd "set use_gui $USE_GUI"

puts $fd {

    # Capture waveform data
    log_wave -r /

    # Create waveform window
    create_wave_config cpu_wave

    # CPU signals
    set signals {
        {/tb_cpu_top/i_clk bin}
        {/tb_cpu_top/i_rst_n bin}

        {/tb_cpu_top/dut/o_mem_req bin}
        {/tb_cpu_top/dut/o_mem_we bin}
        {/tb_cpu_top/dut/o_mem_addr hex}
        {/tb_cpu_top/dut/o_mem_wdata hex}
        {/tb_cpu_top/dut/i_mem_rdata hex}
        {/tb_cpu_top/dut/i_mem_ready bin}

        {/tb_cpu_top/dut/u_cu/u_fsm/o_state unsigned}
        {/tb_cpu_top/dut/w_instruction hex}

        {/tb_cpu_top/dut/u_du/u_pc/o_pc hex}

        {/tb_cpu_top/dut/u_du/w_alu_a hex}
        {/tb_cpu_top/dut/u_du/w_alu_b hex}
        {/tb_cpu_top/dut/u_du/w_alu_result hex}

        {/tb_cpu_top/dut/w_zero bin}
        {/tb_cpu_top/dut/w_pc_we bin}
        {/tb_cpu_top/dut/w_pc_sel bin}
        {/tb_cpu_top/dut/w_reg_we bin}

        {/tb_cpu_top/dut/u_du/w_writeback hex}

        {/tb_cpu_top/dut/u_du/u_irf/r_regs[0] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[1] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[2] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[3] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[4] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[5] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[6] hex}
        {/tb_cpu_top/dut/u_du/u_irf/r_regs[7] hex}
    }

    set added 0

    foreach item $signals {
        lassign $item path radix

        if {[catch {add_wave -radix $radix $path} why]} {
            puts "WARNING: $path : $why"
        } else {
            incr added
        }
    }

    if {$added == 0} {
        error "No CPU signals added to waveform window."
    }

    # ---- PASS 1: $finish 시점까지 실행해서 종료 시각(ns)을 구한다 ----
    puts "Running CPU simulation..."
    run -all

    set end_str [current_time]
    if {![regexp {([0-9.]+)\s*([a-z]+)} $end_str -> end_val end_unit]} {
        error "Cannot parse end time: $end_str"
    }
    switch $end_unit {
        fs { set end_ns [expr {$end_val / 1000000.0}] }
        ps { set end_ns [expr {$end_val / 1000.0}] }
        ns { set end_ns $end_val }
        us { set end_ns [expr {$end_val * 1000.0}] }
        ms { set end_ns [expr {$end_val * 1000000.0}] }
        default { error "Unknown time unit: $end_unit" }
    }
    set total_cycles [expr {int($end_ns / $clk_period_ns)}]
    if {$total_cycles > $max_cycles} { set total_cycles $max_cycles }
    puts "Simulation ended at $end_str -> logging $total_cycles cycles"

    # ---- PASS 2: 처음으로 되돌려서 사이클마다 신호값을 output.txt에 기록 ----
    restart

    set out [open output.txt w]
    set names {}
    foreach item $signals {
        lassign $item path radix
        lappend names [file tail $path]
    }
    puts $out "cycle\ttime\t[join $names \t]"

    for {set cyc 0} {$cyc < $total_cycles} {incr cyc} {
        run ${clk_period_ns}ns

        set vals {}
        foreach item $signals {
            lassign $item path radix
            if {[catch {get_value -radix $radix $path} v]} { set v "ERR" }
            lappend vals $v
        }
        puts $out "$cyc\t[current_time]\t[join $vals \t]"
        if {$cyc % 100 == 0} { puts "cycle $cyc / $total_cycles" }
    }
    close $out

    save_wave_config cpu_wave.wcfg
    puts "Simulation finished."

    # GUI 모드가 아니면 여기서 XSim 종료
    if {!$use_gui} { quit }
}

close $fd

# 6. Launch XSim
if {$USE_GUI} {
    puts "STEP 3: Launch XSim GUI"
    exec xsim cpu_mips8_sim \
        -gui \
        -onfinish stop \
        -wdb [file join $root cpu_wave.wdb] \
        -tclbatch $setup \
        >@stdout 2>@stderr
} else {
    puts "STEP 3: Run XSim (batch)"
    exec xsim cpu_mips8_sim \
        -onfinish stop \
        -wdb [file join $root cpu_wave.wdb] \
        -tclbatch $setup \
        >@stdout 2>@stderr
}

# 7. Verify simulation results
foreach name {
    report.rpt
    cpu_wave.wdb
    cpu_wave.wcfg
    output.txt
} {
    set output [file join $root $name]

    if {![file isfile $output]} {
        error "Missing result: $output"
    }

    puts "SAVED: $output"
}

puts "DONE"