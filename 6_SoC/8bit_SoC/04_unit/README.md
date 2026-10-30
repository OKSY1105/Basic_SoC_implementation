# 단위 기능 검증

| 블록 | 코드 | 계획·결과 |
|---|---|---|
| CPU | [기존 CPU 패키지](../rtl/cpu/8bit_CPU) | [01_cpu/test.md](01_cpu/test.md) |
| RAM | [제어기](../rtl/ram/dram_controller.v)·[모델](../sim/models/DRAM/dram.v) | [02_ram/test.md](02_ram/test.md) |
| UART | [RTL](../rtl/uart) | [03_uart/test.md](03_uart/test.md) |
| BUS | [개발 위치](../rtl/bus) | [04_bus/test.md](04_bus/test.md) |

결과에는 날짜·소스 기준 커밋·변경 상태·도구·명령·기대/실제·로그·한계를 남긴다. 컴파일과 기능 시뮬레이션, FPGA 합성/타이밍과 보드 결과를 구분한다.
