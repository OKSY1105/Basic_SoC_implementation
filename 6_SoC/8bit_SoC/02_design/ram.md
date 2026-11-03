# RAM·DRAM 제어기 인계

실제 상위 접근은 8bit 한 바이트다. [제어기](../../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/dram_controller.v)는 [행동 모델](../../../1_RTL/2_TINY_PROJECT/DRAM/dram.v)을 대상으로 하며 실제 외부 DDR PHY를 구현한 것은 아니다.

| 항목 | 현행 코드에서 확인한 동작 |
|---|---|
| 용량 | 16행×16열×8바이트 = 2KiB |
| 로컬 주소 | 11bit: row[10:7], column[6:3], offset[2:0] |
| 요청 | i_req/i_write/i_addr/i_wdata, 동시에 1개 |
| 완료 | clk 상승 에지 req&&ready, ready 1클록, 다음 IDLE에서 재수락 |
| 바이트 대응 | offset 0→[7:0], 쓰기 RMW로 다른 7바이트 보존 |
| 클록 | 모델 CK는 i_clk/4, 실제 DDR 기준 클록으로 확정하지 않음 |
| 파라미터 | 기본 tRCD=9, CL=9, CWL=10; 대체 12/10/11 |
| 오류 | o_error는 현행 모델에서 항상 0, 주소/timeout 오류는 BUS/상위에서 별도 설계 |
| reset | 동기식 active-low, 발행 전 취소; 발행한 RD/WR은 규정대로 drain; 메모리 전체를 지우지 않음 |

위 표는 구현 관찰이다. 과거 RAM history에서 아직 제안으로 적힌 바이트 순서 등을 사용자 직접 선택으로 소급하지 않는다. 이전 history의 정정은 안전 저장이 가능할 때 새 기록으로 남긴다.

PRE/REF·refresh·뱅크 스케줄링·training·PHY/보드 검증은 미구현이다. FPGA 실물에서 이 모델을 그대로 합성해 RAM으로 쓰는 계획으로 취급하지 않는다. 실제 FPGA 메모리/외부 DRAM 구현 방법은 별도 결정한다.

## FPGA RAM 방향 — 2026-11-03 사용자 결정

직접 만든 메모리 제어기를 보드(ZYNQ-7020)에서 동작시키기 위해 **A + 캐시** 방향으로 간다. ZYNQ 보드의 DDR3는 PS 전용이라 이 제어기가 구동할 수 없으므로, DRAM 소자는 FPGA 안의 BRAM 기반 동작 모델로 대신한다.

```text
AHB 디코더 → 캐시(Cache/cache.v) → DRAM 제어기 → DRAM 동작 모델
             AHB-Lite slave,      (줄 단위 포트 추가 필요)  (시뮬레이션: dram.v / 보드: BRAM 기반 합성 가능 모델, 신규)
             8줄×8B, write-back
```

| 항목 | 상태 |
|---|---|
| 캐시 | [Cache/README.md](../../../1_RTL/2_TINY_PROJECT/Cache/README.md) — 직접 사상 8줄×8바이트, write-back·write-allocate, AHB-Lite slave 단자(RAM AHB 래퍼를 합침), 단독 시험 통과 |
| 제어기 줄 단위 포트 | 캐시의 64bit 줄 요청을 받아 RD/WR burst 1회로 처리(바이트 RMW 불필요). 미구현 |
| DQ/DQS 분리 | FPGA 내부에는 양방향 버퍼가 없으므로 출력·입력·출력 enable로 나눈다. 미구현 |
| 합성 가능 DRAM 모델 | BRAM 저장 + 시스템 클록 기준 명령·지연 카운터. 기존 제어기 TB를 기존 모델과 새 모델 양쪽으로 통과시켜 동작 일치를 확인한다. 미구현 |
