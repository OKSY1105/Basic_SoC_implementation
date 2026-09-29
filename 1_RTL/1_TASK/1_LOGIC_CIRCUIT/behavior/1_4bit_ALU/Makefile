clean:
	rm -rf cds.lib hdl.var *.lib waves.shm *.log *.key *.dsn *.trn *.vcd \
		.simvision .symbol* xcelium.d work.lib

set:
	touch cds.lib hdl.var
	mkdir -p work.lib
	echo "define work_lib ./work.lib" > ./cds.lib
	echo "define WORK work_lib" > ./hdl.var

compile:
	xmvlog -MESS -linedebug ./*v

elab:
	xmelab -MESS -access rwc tb_ALU_4bit

sim:
	xmsim -MESS -gui tb_ALU_4bit
synth:
	@echo "set_db library /home/hah010/Basic_SoC_implementation/5_APR/1_LIB/typical.lib" > synth.tcl
	@echo "read_hdl ALU_4bit.v" >> synth.tcl
	@echo "elaborate ALU_4bit" >> synth.tcl
	@echo "gui_show" >> synth.tcl
	genus -gui -f synth.tcl

all: clean set compile elab sim
