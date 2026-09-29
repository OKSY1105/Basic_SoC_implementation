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


































