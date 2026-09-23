# -timescale : To mention the time unit and time precision
# -access : Passed to the elaborator to provide read access to simulation objects
# -gui : To invoke the xrun in gui mode
# -mess : To display all to the messages in detail
# -define : To provide SDF definition present in the testbench file
# -v : To provide library in ".v" format
# +libext : library extention
# +libext+.v -y : xrun would compile .v files automatically in the specific folder decribed with -y option 

# HEX file is defined at ../TESTBENCH/tb_cmsdk_mcu.v 

xrun -64bit \
    -timescale 1ns/10ps \
    +max_err_count+50 \
    +define+function_sim \
    +difine+PAD_TEST \
    -access +rwc \
    -profile \
    -profthread \
     +libext+.v \
    ../TESTBENCH/tb_uart.v \
    ../../RTL/uart_top.v \
    /GPDK045/digital/giolib045_v3.5/vlog/pads_FF_s1vg.v \
    /GPDK045/digital/gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
    -l func_sim.log




# ../TESTBENCH/tb_register.v \
#  ../../RTL/register.v \
   #
   #   #    ../../../../../1_RTL/1_TASK/2_SYSTEM_DESIGN/40_N-bit_Shift_Register/*.v \
   #   #    /GPDK045/digital/giolib045_v3.5/vlog/pads_FF_s1vg.v \
   #   #    /GPDK045/digital/gsclib045_all_v4.4/gsclib045_svt_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
   #
   #   #    -l func_sim.log
   #
