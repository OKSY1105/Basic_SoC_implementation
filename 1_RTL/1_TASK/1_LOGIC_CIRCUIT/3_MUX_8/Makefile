# ==== 설정 ====
SIM_TOP = tb_multi_2bit

RTL_TOP = multi_2bit

SRC     = *.v                             
VIVADO  = /home/sean/Vivado/2024.2/bin    

export PATH := $(VIVADO):$(PATH)

clean:
	rm -rf xsim.dir *.jou *.log *.pb .Xil *.wdb *.vcd webtalk*

compile:
	xvlog -sv $(SRC)

elab:
	xelab -debug typical $(SIM_TOP) -s $(SIM_TOP)_sim

sim:
	xsim $(strip $(SIM_TOP))_sim -gui

sim_batch :
	xsim $(strip $(SIM_TOP))_sim -R

schematic:
	TOP=$(RTL_TOP) vivado -mode gui -source schematic.tcl

all: clean compile elab sim

.PHONY: clean compile elab sim all schematic







xclean :
	rm -rf cds.lib hdl.var *.lib waves.shm *.log *.key *.dsn *.trn *.vcd \
                .simvision .symbol* xcelium.d


xset:
	touch cds.lib hdl.var
	mkdir work.lib
	echo "define work_lib ./work.lib" >> ./cds.lib
	echo "define WORK work_lib" >> ./hdl.var

xcompile:
	xmvlog -MESS -linedebug ./*v

xelab:
	xmelab -MESS -access rwc tb_mux_8_1

xsim:
	xmsim -MESS tb_mux_8_1 -gui

xall:	xclean xset xcompile xelab xsim






























