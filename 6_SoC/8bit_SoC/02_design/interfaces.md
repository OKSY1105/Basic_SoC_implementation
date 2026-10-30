# 공유 인터페이스와 주소 기준

| 경계 | 현재 폭/단위 | 상태 |
|---|---|---|
| CPU instruction | 주소 16bit word, 명령 16bit | 기존 구현 |
| CPU data | 주소 16bit byte, 데이터 8bit, req/ready/error | 기존 구현 |
| RAM 제어기 host | 주소 11bit byte, 데이터 8bit, 요청 동시 1개 | 기존 구현, BUS 어댑터 필요 |
| UART host | THR write/RHR read pulse, 데이터와 FIFO/LSR 상태 | 기존 구현, MMIO 어댑터 필요 |
| CPU→BUS→slave | 선택·보관·오류·완료 시간표 | 미구현/세부 설계 필요 |
| PC→FPGA→STM32 | signed8 요청·signed16 결과·몫/나머지 | 응용 목표, wire packet 미정 |

## 기존 CPU TB 주소 모델

| 주소 | 기존 TB의 의미 | 실제 SoC 상태 |
|---|---|---|
| 0000~07FF | 2KiB RAM | BUS decoding 미구현 |
| FF00 | UART RX data 읽기 | MMIO 어댑터 미구현 |
| FF01 | UART TX data 쓰기 | MMIO 어댑터 미구현 |
| FF02 | UART status 읽기 | status 비트/실제 연결 미확정 |

이 표는 기존 CPU 시험 모델을 인계한 기준이며 새 전체 SoC 최종 주소 맵을 확정한 것이 아니다. ROM의 word 주소와 데이터 byte 주소를 그대로 같은 공간으로 합치지 않는다.

## 요청 완료 규칙에서 확인할 것

CPU와 DRAM의 각 포트에서 clk 상승 에지 req&&ready를 완료로 삼는다. 처리 중 주소/데이터를 유지한다. slave 재수락 간격, reset 중 drain, UART FIFO side effect는 연결 회로와 TB가 함께 검증해야 한다. ready가 올라간 기간을 여러 번의 쓰기나 RX pop으로 해석하지 않는다.
