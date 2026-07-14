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
	xmelab -MESS -access rwc ALU_4bit

sim:
	xmsim -MESS -gui ALU_4bit

all: clean set compile elab sim
