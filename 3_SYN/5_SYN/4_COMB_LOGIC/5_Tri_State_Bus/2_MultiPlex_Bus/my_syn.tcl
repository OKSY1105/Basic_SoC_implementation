set_db init_lib_search_path /home/hah010/Basic_SoC_implementation/3_SYN/1_LIB 
set_db init_hdl_search_path /home/hah010/Basic_SoC_implementation/1_RTL/4_COMB_LOGIC/5_Tri_State_Bus/2_MultiPlex_Bus

read_libs slow_vdd1v0_basicCells.lib
read_hdl data_bus_driver.v

elaborate

read_sdc /home/hah010/Basic_SoC_implementation/3_SYN/2_CONSTRAINTS/sample.sdc

set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic
syn_map
syn_opt

report_timing > ./reports/timing.rpt
report_power > ./reports/power.rpt
report_qor > ./reports/qor.rpt
report_area > ./reports/area.rpt

write_hdl > ./outputs/data_bus_driver_netlist.v
write_sdc > ./outputs/data_bus_driver_final.sdc
