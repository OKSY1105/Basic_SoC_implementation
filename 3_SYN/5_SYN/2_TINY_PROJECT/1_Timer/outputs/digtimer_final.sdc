# ####################################################################

#  Created by Genus(TM) Synthesis Solution 22.17-s071_1 on Thu Jul 09 06:44:21 KST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design digtimer

create_clock -name "clk" -period 10.0 -waveform {0.0 5.0} [get_ports clk]
set_clock_transition 0.1 [get_clocks clk]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports rst]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_sec[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_sec[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_sec[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_sec[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_sec[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_sec[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_min[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_min[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_min[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_min[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_min[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_min[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_hour[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_hour[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_hour[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {o_hour[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_data[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_sel[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg1_sel[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_data[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_sel[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg2_sel[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_data[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_sel[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {seg3_sel[0]}]
set_wire_load_mode "enclosed"
set_clock_uncertainty -setup 0.01 [get_ports clk]
set_clock_uncertainty -hold 0.01 [get_ports clk]
