#set_db library /usr/cadence/genus/share/genus/libs/tech/gtech/gtech.db 
set_db init_hdl_search_path /home/hah010/Basic_SoC_implementation/1_RTL/1_TASK/1_LOGIC_CIRCUIT/behavior/1_4bit_ALU 

#read_libs slow_vdd1v0_basicCells.lib
read_hdl ALU_4bit.v 

elaborate

read_sdc /home/hah010/Basic_SoC_implementation/3_SYN/2_CONSTRAINTS/sample.sdc

set_db syn_generic_effort medium
#set_db syn_map_effort medium
#set_db syn_opt_effort medium

syn_generic
#syn_map
#syn_opt

#report_timing > ./reports/timing.rpt
#report_power > ./reports/power.rpt
#report_qor > ./reports/qor.rpt
#report_area > ./reports/area.rpt

#write_hdl > ./outputs/ALU_4bit_netlist.v
#write_sdc > ./outputs/ALU_4bit_final.sdc

gui_show
