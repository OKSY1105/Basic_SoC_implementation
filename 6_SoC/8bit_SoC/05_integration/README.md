# 통합 계획

| 순서 | 연결 | 통과 기준 | 상태 |
|---|---|---|---|
| I01 | ROM→CPU→BUS→RAM | LD/ADD/ST 프로그램, 저장값·stall·완료 횟수 일치 | 시뮬레이션 PASS(2026-11-04) — [통합 TB](../tb/soc/README.md) `ram_basic`·fault 2종·`reset_mid_run` |
| I02 | BUS→UART MMIO | RX pop/TX push 정확히 1회, FIFO 대기·status·reset | 시뮬레이션 PASS(2026-11-04) — 통합 TB `uart_echo_irq`(인터럽트, 송신 클록 ±1.5%, 115200 bps 포함) |
| I03 | ROM 계산기 프로그램 | signed8 두 수→signed16 일곱 연산(ADD·SUB·MUL·DIV·POW·GCD·SQR), 몫/나머지·오류 5종 | v1 시뮬레이션 PASS(2026-11-04), v2 자체 XSim 두 모델 fast·real PASS(2026-11-24), VR-016 대기 — [`firmware/calc.asm`](../firmware/README.md), 통합 TB `calc`([계산기 통신 규약](../02_design/calculator.md) 사례·오류·무작위 줄, 115200 bps 포함) |
| I04 | PC→FPGA→STM32 | 요청/응답 프레임 일치와 LCD 표시 | v1 보드 결합 기록은 [PC 도구](../pc_tools/README.md). v2 실물·MSPM0 시험은 미실행 |

첫 통합에서는 기존 UART TB 모델을 실제 UART로 오인하지 않는다. RAM 행동 모델 통합과 실물 FPGA 메모리 통합도 결과를 나눠 기록한다. SoC top RTL([`rtl/soc/soc8_top.v`](../rtl/soc/README.md))과 통합 TB([`tb/soc`](../tb/soc/README.md))는 2026-11-04에 구현했다. 초기 I01~I03은 DRAM 행동 모델 시뮬레이션이며 v1은 이후 VR-011을 거쳐 main에 병합했다. v2 펌웨어·통합의 자체 시험과 남은 VR-016은 [통합 TB](../tb/soc/README.md)의 최신 절을 따른다. 통합 TB가 UART 수신 코어의 연속 프레임 결함을 찾아 고쳤다([uart.md](../02_design/uart.md) 코어 변경 절).
