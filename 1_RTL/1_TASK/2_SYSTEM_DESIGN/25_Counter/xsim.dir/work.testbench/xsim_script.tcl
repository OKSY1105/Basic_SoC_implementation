set_param project.enableReportConfiguration 0
load_feature core
current_fileset
xsim {work.testbench} -wdb {sim_tb.wdb} -autoloadwcfg -tclbatch {sgdh_sim.tcl}
