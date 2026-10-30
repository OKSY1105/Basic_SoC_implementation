# 통합 계획 — 미구현

| 순서 | 연결 | 통과 기준 |
|---|---|---|
| I01 | ROM→CPU→BUS→RAM | LD/ADD/ST 프로그램, 저장값·stall·완료 횟수 일치 |
| I02 | BUS→UART MMIO | RX pop/TX push 정확히 1회, FIFO 대기·status·reset |
| I03 | ROM 계산기 프로그램 | signed8 두 수→signed16 ADD/SUB/MUL/DIV, 몫/나머지 |
| I04 | PC→FPGA→STM32 | 요청/응답 프레임 일치와 LCD 표시 |

첫 통합에서는 기존 UART TB 모델을 실제 UART로 오인하지 않는다. RAM 행동 모델 통합과 실물 FPGA 메모리 통합도 결과를 나눠 기록한다. 아직 soc_top RTL이나 통합 PASS는 없다.
