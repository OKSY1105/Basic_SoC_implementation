#!/usr/bin/env -S vivado -mode batch -nojournal -nolog -source

set SCRIPT_DIR [file dirname [file normalize [info script]]]

puts "========================================"
puts " Vivado clean"
puts " Path : $SCRIPT_DIR"
puts "========================================"


# ============================================================
# Vivado / XSim 생성 디렉터리
# ============================================================

foreach dir_name {
    vivado_sim
    vivado_work
    .Xil
    xsim.dir
} {

    set path [file join $SCRIPT_DIR $dir_name]

    if {[file exists $path]} {

        puts "DELETE DIR : $path"

        file delete -force $path

    }

}


# ============================================================
# Vivado log / journal / backup
# ============================================================

foreach pattern {

    vivado*.log
    vivado*.jou

    *.wdb
    *.wcfg
    *.str
    *.pb

    webtalk*.log
    webtalk*.jou

    usage_statistics_webtalk.xml

} {

    foreach path [glob -nocomplain \
                       -directory $SCRIPT_DIR \
                       $pattern] {

        puts "DELETE FILE : $path"

        file delete -force $path

    }

}


puts "========================================"
puts " CLEAN COMPLETE"
puts "========================================"

exit
