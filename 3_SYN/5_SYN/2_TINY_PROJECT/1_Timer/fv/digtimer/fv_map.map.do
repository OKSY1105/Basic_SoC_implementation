
//input ports
add mapped point rst rst -type PI PI
add mapped point clk clk -type PI PI

//output ports
add mapped point o_sec[5] o_sec[5] -type PO PO
add mapped point o_sec[4] o_sec[4] -type PO PO
add mapped point o_sec[3] o_sec[3] -type PO PO
add mapped point o_sec[2] o_sec[2] -type PO PO
add mapped point o_sec[1] o_sec[1] -type PO PO
add mapped point o_sec[0] o_sec[0] -type PO PO
add mapped point o_min[5] o_min[5] -type PO PO
add mapped point o_min[4] o_min[4] -type PO PO
add mapped point o_min[3] o_min[3] -type PO PO
add mapped point o_min[2] o_min[2] -type PO PO
add mapped point o_min[1] o_min[1] -type PO PO
add mapped point o_min[0] o_min[0] -type PO PO
add mapped point o_hour[3] o_hour[3] -type PO PO
add mapped point o_hour[2] o_hour[2] -type PO PO
add mapped point o_hour[1] o_hour[1] -type PO PO
add mapped point o_hour[0] o_hour[0] -type PO PO
add mapped point seg1_data[7] seg1_data[7] -type PO PO
add mapped point seg1_data[6] seg1_data[6] -type PO PO
add mapped point seg1_data[5] seg1_data[5] -type PO PO
add mapped point seg1_data[4] seg1_data[4] -type PO PO
add mapped point seg1_data[3] seg1_data[3] -type PO PO
add mapped point seg1_data[2] seg1_data[2] -type PO PO
add mapped point seg1_data[1] seg1_data[1] -type PO PO
add mapped point seg1_data[0] seg1_data[0] -type PO PO
add mapped point seg1_sel[1] seg1_sel[1] -type PO PO
add mapped point seg1_sel[0] seg1_sel[0] -type PO PO
add mapped point seg2_data[7] seg2_data[7] -type PO PO
add mapped point seg2_data[6] seg2_data[6] -type PO PO
add mapped point seg2_data[5] seg2_data[5] -type PO PO
add mapped point seg2_data[4] seg2_data[4] -type PO PO
add mapped point seg2_data[3] seg2_data[3] -type PO PO
add mapped point seg2_data[2] seg2_data[2] -type PO PO
add mapped point seg2_data[1] seg2_data[1] -type PO PO
add mapped point seg2_data[0] seg2_data[0] -type PO PO
add mapped point seg2_sel[1] seg2_sel[1] -type PO PO
add mapped point seg2_sel[0] seg2_sel[0] -type PO PO
add mapped point seg3_data[7] seg3_data[7] -type PO PO
add mapped point seg3_data[6] seg3_data[6] -type PO PO
add mapped point seg3_data[5] seg3_data[5] -type PO PO
add mapped point seg3_data[4] seg3_data[4] -type PO PO
add mapped point seg3_data[3] seg3_data[3] -type PO PO
add mapped point seg3_data[2] seg3_data[2] -type PO PO
add mapped point seg3_data[1] seg3_data[1] -type PO PO
add mapped point seg3_data[0] seg3_data[0] -type PO PO
add mapped point seg3_sel[1] seg3_sel[1] -type PO PO
add mapped point seg3_sel[0] seg3_sel[0] -type PO PO

//inout ports




//Sequential Pins
add mapped point ctrl_hour/fnd_data[7]/q ctrl_hour/fnd_data_reg[7]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_data[4]/q ctrl_hour/fnd_data_reg[4]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_data[3]/q ctrl_hour/fnd_data_reg[3]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_data[2]/q ctrl_hour/fnd_data_reg[2]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_data[6]/q ctrl_hour/fnd_data_reg[6]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_data[5]/q ctrl_hour/fnd_data_reg[5]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_data[1]/q ctrl_hour/fnd_data_reg[1]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_sel[0]/q ctrl_hour/fnd_sel_reg[0]/Q -type DFF DFF
add mapped point ctrl_hour/fnd_sel[1]/q ctrl_hour/fnd_sel_reg[1]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[7]/q ctrl_min/fnd_data_reg[7]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[6]/q ctrl_min/fnd_data_reg[6]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[4]/q ctrl_min/fnd_data_reg[4]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[2]/q ctrl_min/fnd_data_reg[2]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[5]/q ctrl_min/fnd_data_reg[5]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[3]/q ctrl_min/fnd_data_reg[3]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[1]/q ctrl_min/fnd_data_reg[1]/Q -type DFF DFF
add mapped point ctrl_min/fnd_data[0]/q ctrl_min/fnd_data_reg[0]/Q -type DFF DFF
add mapped point ctrl_min/fnd_sel[0]/q ctrl_min/fnd_sel_reg[0]/Q -type DFF DFF
add mapped point ctrl_min/fnd_sel[1]/q ctrl_min/fnd_sel_reg[1]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[7]/q ctrl_sec/fnd_data_reg[7]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[6]/q ctrl_sec/fnd_data_reg[6]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[4]/q ctrl_sec/fnd_data_reg[4]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[2]/q ctrl_sec/fnd_data_reg[2]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[5]/q ctrl_sec/fnd_data_reg[5]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[3]/q ctrl_sec/fnd_data_reg[3]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[1]/q ctrl_sec/fnd_data_reg[1]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_data[0]/q ctrl_sec/fnd_data_reg[0]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_sel[0]/q ctrl_sec/fnd_sel_reg[0]/Q -type DFF DFF
add mapped point ctrl_sec/fnd_sel[1]/q ctrl_sec/fnd_sel_reg[1]/Q -type DFF DFF
add mapped point ut_hour/hour[2]/q ut_hour/hour_reg[2]/Q -type DFF DFF
add mapped point ut_hour/hour[1]/q ut_hour/hour_reg[1]/Q -type DFF DFF
add mapped point ut_hour/hour[3]/q ut_hour/hour_reg[3]/Q -type DFF DFF
add mapped point ut_hour/hour[0]/q ut_hour/hour_reg[0]/Q -type DFF DFF
add mapped point ut_hour/pre_min[0]/q ut_hour/pre_min_reg[0]/Q -type DFF DFF
add mapped point ut_hour/pre_min[1]/q ut_hour/pre_min_reg[1]/Q -type DFF DFF
add mapped point ut_hour/pre_min[2]/q ut_hour/pre_min_reg[2]/Q -type DFF DFF
add mapped point ut_hour/pre_min[5]/q ut_hour/pre_min_reg[5]/Q -type DFF DFF
add mapped point ut_hour/pre_min[3]/q ut_hour/pre_min_reg[3]/Q -type DFF DFF
add mapped point ut_hour/pre_min[4]/q ut_hour/pre_min_reg[4]/Q -type DFF DFF
add mapped point ut_min/min[4]/q ut_min/min_reg[4]/Q -type DFF DFF
add mapped point ut_min/min[3]/q ut_min/min_reg[3]/Q -type DFF DFF
add mapped point ut_min/min[1]/q ut_min/min_reg[1]/Q -type DFF DFF
add mapped point ut_min/min[2]/q ut_min/min_reg[2]/Q -type DFF DFF
add mapped point ut_min/min[5]/q ut_min/min_reg[5]/Q -type DFF DFF
add mapped point ut_min/min[0]/q ut_min/min_reg[0]/Q -type DFF DFF
add mapped point ut_min/pre_sec[1]/q ut_min/pre_sec_reg[1]/Q -type DFF DFF
add mapped point ut_min/pre_sec[3]/q ut_min/pre_sec_reg[3]/Q -type DFF DFF
add mapped point ut_min/pre_sec[2]/q ut_min/pre_sec_reg[2]/Q -type DFF DFF
add mapped point ut_min/pre_sec[4]/q ut_min/pre_sec_reg[4]/Q -type DFF DFF
add mapped point ut_min/pre_sec[5]/q ut_min/pre_sec_reg[5]/Q -type DFF DFF
add mapped point ut_min/pre_sec[0]/q ut_min/pre_sec_reg[0]/Q -type DFF DFF
add mapped point ut_sec/sec[4]/q ut_sec/sec_reg[4]/Q -type DFF DFF
add mapped point ut_sec/sec[3]/q ut_sec/sec_reg[3]/Q -type DFF DFF
add mapped point ut_sec/sec[5]/q ut_sec/sec_reg[5]/Q -type DFF DFF
add mapped point ut_sec/sec[2]/q ut_sec/sec_reg[2]/Q -type DFF DFF
add mapped point ut_sec/sec[1]/q ut_sec/sec_reg[1]/Q -type DFF DFF
add mapped point ut_sec/sec[0]/q ut_sec/sec_reg[0]/Q -type DFF DFF
add mapped point ut_sec/cnt[6]/q ut_sec/cnt_reg[6]/Q -type DFF DFF
add mapped point ut_sec/cnt[3]/q ut_sec/cnt_reg[3]/Q -type DFF DFF
add mapped point ut_sec/cnt[4]/q ut_sec/cnt_reg[4]/Q -type DFF DFF
add mapped point ut_sec/cnt[5]/q ut_sec/cnt_reg[5]/Q -type DFF DFF
add mapped point ut_sec/cnt[1]/q ut_sec/cnt_reg[1]/Q -type DFF DFF
add mapped point ut_sec/cnt[7]/q ut_sec/cnt_reg[7]/Q -type DFF DFF
add mapped point ut_sec/cnt[8]/q ut_sec/cnt_reg[8]/Q -type DFF DFF
add mapped point ut_sec/cnt[2]/q ut_sec/cnt_reg[2]/Q -type DFF DFF
add mapped point ut_sec/cnt[11]/q ut_sec/cnt_reg[11]/Q -type DFF DFF
add mapped point ut_sec/cnt[12]/q ut_sec/cnt_reg[12]/Q -type DFF DFF
add mapped point ut_sec/cnt[14]/q ut_sec/cnt_reg[14]/Q -type DFF DFF
add mapped point ut_sec/cnt[13]/q ut_sec/cnt_reg[13]/Q -type DFF DFF
add mapped point ut_sec/cnt[15]/q ut_sec/cnt_reg[15]/Q -type DFF DFF
add mapped point ut_sec/cnt[16]/q ut_sec/cnt_reg[16]/Q -type DFF DFF
add mapped point ut_sec/cnt[0]/q ut_sec/cnt_reg[0]/Q -type DFF DFF
add mapped point ut_sec/cnt[9]/q ut_sec/cnt_reg[9]/Q -type DFF DFF
add mapped point ut_sec/cnt[10]/q ut_sec/cnt_reg[10]/Q -type DFF DFF



//Black Boxes



//Empty Modules as Blackboxes
