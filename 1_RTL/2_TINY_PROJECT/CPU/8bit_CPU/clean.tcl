
#!/bin/sh
# \
exec tclsh "$0" "$@"

set root [file normalize [file dirname [info script]]]

# 삭제할 파일 및 디렉터리
set exact_names {
    report.rpt
    cpu_wave.wdb
    cpu_wave.wcfg

    .xsim_gui_setup.tcl
    .xsim_auto_wave.tcl

    xsim.dir
    .Xil

    xvlog.log
    xvlog.pb
    xvlog.jou

    xelab.log
    xelab.pb
    xelab.jou

    xsim.log
    xsim.jou

    vivado.log
    vivado.jou

    webtalk.log
    webtalk.jou

    compile.log
    elaborate.log
    simulate.log
}

# Vivado / XSim 백업 로그
set patterns {
    vivado_*.backup.log
    vivado_*.backup.jou
    xsim_*.backup.log
    xsim_*.backup.jou
}

# 삭제 대상 수집
set targets {}

foreach name $exact_names {
    lappend targets [file join $root $name]
}

foreach pattern $patterns {
    foreach path [glob -nocomplain -directory $root -- $pattern] {
        lappend targets $path
    }
}

# 파일 및 디렉터리 삭제
set failed 0

foreach path [lsort -unique $targets] {

    if {![file exists $path]} {
        continue
    }

    if {[catch {file delete -force -- $path} err]} {
        puts stderr "ERROR: $path: $err"
        set failed 1
    } else {
        puts "DELETED: [file tail $path]"
    }
}

if {$failed} {
    error "CLEAN FAILED"
}

puts "CLEAN COMPLETE"
