# RTL schematic generation

set part "xc7z020clg400-1"
set project "sean_schematic"
set location "./sean_schematic"

create_project $project $location -part $part -force

# Read RTL source files
foreach src [glob -nocomplain "./design/*.v"] {
    read_verilog $src
}

# Read testbench source files
foreach tb [glob -nocomplain "./testbench/*.v"] {
    read_verilog $tb
}

# Set the simulation hierarchy as the top module
set_property top testbench [current_fileset]

# Run RTL synthesis
synth_design -rtl -rtl_skip_mlo -name sean_rtl
