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
