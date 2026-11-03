# 공유 인터페이스와 주소 기준

| 경계 | 현재 폭/단위 | 상태 |
|---|---|---|
| CPU instruction | AHB-Lite, `HADDR` 17bit byte(2×PC), `HRDATA` 16bit → ROM 포트 A 점대점 | 구현(M1·M5, `feat/8bit-soc`). 모듈 검증 때 Codex 검증 — [변경안](cpu_ahb_port.md)·[ROM](../rtl/rom/README.md) |
| CPU data | AHB-Lite, `HADDR` 16bit byte(X), 데이터 8bit, `HREADY`/`HRESP` → AHB 디코더 | 구현(M1·M6, `feat/8bit-soc`). 모듈 검증 때 Codex 검증 — [변경안](cpu_ahb_port.md)·[bus.md](bus.md) |
| RAM (캐시) | AHB-Lite slave(바이트), 아래쪽 64bit 줄 req/ack | 구현(M2) — [Cache](../../../1_RTL/2_TINY_PROJECT/Cache/README.md) |
| RAM 제어기 host | 주소 11bit byte, 데이터 8bit 또는 64bit 줄(`i_line`), 요청 동시 1개 | 구현. 캐시용 64bit 줄 포트·DQ/DQS 분리 코어 추가(M3) — [ram.md](ram.md)·[DRAM 제어기](../../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/README.md) |
| UART host | THR write/RHR read pulse, 데이터와 FIFO/LSR 상태 | 기존 구현(오류 flag 지우기 입력 추가). APB 래퍼(M9)가 0xFF00~0xFF04 레지스터와 IRQ로 연결 — 구현, [uart.md](uart.md) |
| CPU→BUS→slave | 선택·보관·오류·완료 시간표 | AHB 디코더·응답 선택기·기본 slave(M6), AHB→APB3 브리지(M8) 구현 — [bus.md](bus.md) |
| UART IRQ → CPU | 1bit level, `i_clk` 동기(UART 래퍼 `o_irq` 레지스터 출력 → CPU `i_irq`) | 구현(M9·M11). 벡터 PC 0x0002 — [cpu.md](cpu.md)·[uart.md](uart.md) |
| 리셋 | 보드 reset(버튼 AND MMCM locked, active low) → `reset_sync`(비동기 assert·동기 해제) → 모든 모듈의 active-low reset. CPU·DRAM 제어기는 동기식, 캐시·ROM·버스·UART는 비동기식으로 받는다 | 구현(M10) — [BUS README](../../../1_RTL/2_TINY_PROJECT/BUS/README.md) |
| PC→FPGA→STM32 | signed8 요청·signed16 결과·몫/나머지 | 응용 목표, wire packet 미정 |

## 기존 CPU TB 주소 모델

| 주소 | 기존 TB의 의미 | 실제 SoC 상태 |
|---|---|---|
| 0000~07FF | 2KiB RAM | SoC에서는 ROM 영역(0x0000~0x1FFF). RAM은 0x8000~0x87FF |
| FF00 | UART RX data 읽기 | UART 래퍼 RX_DATA (M9) |
| FF01 | UART TX data 쓰기 | UART 래퍼 TX_DATA (M9) |
| FF02 | UART status 읽기 | UART 래퍼 STATUS, bit 배치는 [uart.md](uart.md) M9 절 (M9) |

이 표는 기존 CPU 시험 모델을 인계한 기준이다. SoC 주소 맵은 [bus.md](bus.md) "버스 구성과 공통 규칙" 절을 따른다. ROM의 word 주소와 데이터 byte 주소를 그대로 같은 공간으로 합치지 않는다.

## 요청 완료 규칙에서 확인할 것

DRAM 제어기 host 포트와 캐시의 줄 포트는 clk 상승 에지 req&&ready(ack)를 완료로 삼는다. CPU 포트와 버스는 AHB-Lite이며 [변경안](cpu_ahb_port.md)과 [bus.md](bus.md)의 주소·데이터 단계 시간표를 따른다. 처리 중 주소/데이터를 유지한다. slave 재수락 간격, reset 중 drain, UART FIFO side effect는 연결 회로와 TB가 함께 검증해야 한다. ready가 올라간 기간을 여러 번의 쓰기나 RX pop으로 해석하지 않는다.
