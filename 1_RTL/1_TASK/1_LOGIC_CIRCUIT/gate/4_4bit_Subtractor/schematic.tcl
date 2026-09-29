# 1. Makefile에서 넘겨준 TOP 변수(sub_4bit) 가져오기
set top_module $env(TOP)

# 2. 현재 폴더에 있는 모든 Verilog 파일 읽기
read_verilog [glob *.v]

# 3. RTL 설계 분석 (이 과정을 거쳐야 스키매틱을 그릴 수 있음)
synth_design -rtl -top $top_module

# 4. 스키매틱 창 띄우기
show_schematic
