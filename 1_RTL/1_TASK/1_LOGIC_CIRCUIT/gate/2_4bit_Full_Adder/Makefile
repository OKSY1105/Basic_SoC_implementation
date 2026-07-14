# ==== 설정 ====
TOP = tb_FA_4bit
SRC     = *.v                             
VIVADO  = /home/sean/Vivado/2024.2/bin    

export PATH := $(VIVADO):$(PATH)

clean:
	rm -rf xsim.dir *.jou *.log *.pb .Xil *.wdb *.vcd webtalk*

compile:
	xvlog -sv $(SRC)

elab:
	xelab -debug typical $(TOP) -s $(TOP)_sim

sim:
	xsim $(strip $(TOP))_sim -gui

sim_batch :
	xsim $(strip $(TOP))_sim -R

schematic:
	TOP=$(TOP) vivado -mode gui -source schematic.tcl

all: clean compile elab sim

.PHONY: clean compile elab sim all schematic


































