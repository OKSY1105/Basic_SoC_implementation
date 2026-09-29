set_param project.enableReportConfiguration 0
load_feature core
current_fileset
xsim {work.tb_flip_flop} -wdb {sim_tb.wdb} -autoloadwcfg -tclbatch {sean_sim.tcl}
