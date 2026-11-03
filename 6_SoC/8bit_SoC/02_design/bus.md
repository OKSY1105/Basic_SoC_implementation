# BUS 설계 과제 — 구현 중

재사용 BUS 원본 개발 위치는 [1_RTL BUS](../../../1_RTL/2_TINY_PROJECT/BUS)이며, SoC별 주소 디코더/어댑터는 [rtl/bus](../rtl/bus), 통합 시험은 [tb/bus](../tb/bus)에 둔다. 데이터 포트 디코더·응답 선택기·기본 slave(M6)는 [soc8_ahb_bus.v](../rtl/bus/soc8_ahb_bus.v)에, ROM(M5)은 [soc8_rom.v](../rtl/rom/soc8_rom.v)에 구현했다. APB 브리지·UART 래퍼·SoC top은 아직 없다.

## 결정 — 2026-10-30

| 항목 | 내용 | 상태 |
|---|---|---|
| 메모리 구조 | 수정 하버드: CPU 코어의 명령/데이터 포트는 분리 유지, 시스템은 ROM·RAM·UART를 단일 주소 맵에 배치 | 사용자 확정 |
| 버스 | 직접 정의한 req/ready 대신 표준 AMBA 프로토콜 | 사용자 확정 |
| 프로토콜 조합 | AHB-Lite(ROM·RAM) + AHB-to-APB 브리지 + APB3(UART) | 사용자 확정(2026-11-02) |
| 단계 | 1차: 명령 포트(AHB-Lite)→ROM 포트 A 점대점, 데이터 포트(AHB-Lite)→디코더(단일 master). 2차: 명령 포트를 버스에 연결하고 중재기 추가 | 추천안, 진행 기준 |
| CPU 코어 | ISA·3단계·stall 유지, 명령·데이터 포트를 AHB-Lite master로 변경(변환기 없음). 경로·시간표·대기·분기 취소 규칙은 [CPU AHB 포트 변경안](cpu_ahb_port.md) | 사용자 확정(2026-11-02), 구현(M1, `feat/8bit-soc`) |

아래 표의 각 항목은 이 결정을 기준으로 AHB-Lite/APB 신호(HTRANS·HREADY·HRESP, PSEL·PENABLE·PREADY·PSLVERR)로 구체화한다.

| 정할 항목 | 필요한 동작/시험 |
|---|---|
| 주소 디코딩 | 16bit byte 주소에서 RAM/UART 선택, 미할당 접근 오류 |
| 로컬 주소 변환 | RAM 영역 확인 뒤 11bit로 변환; 단순 하위 bit 절단 alias 금지 |
| 대기 | 요청·주소·쓰기 데이터 보관, slave 완료 전 CPU stall |
| 응답 | 선택한 slave의 ready/rdata/error만 반영 |
| 부작용 | 한 완료당 UART pop/push·메모리 쓰기 각각 1회 |
| reset | 진행 중 취소/이미 반영된 쓰기/drain 규칙 합의 |
| 명령 연결 | 1차는 명령 포트→ROM 포트 A 점대점 ([변경안](cpu_ahb_port.md) 3절) |

단위 시험은 최초/최종 주소·미할당·back-to-back·긴 wait·reset 중 접근·중복 완료·비선택 slave의 가짜 ready를 포함한다. 통합 전 포트 시간표와 기대 결과를 문서화한다.

## 버스 구성과 공통 규칙 — 2026-11-03

```text
CPU 명령 포트 ─────────────────────────▶ ROM 포트 A (16bit, 점대점)
CPU 데이터 포트 ─▶ AHB 디코더(M6) ─┬─▶ ROM 포트 B (읽기 전용)        0x0000~0x1FFF
                                   ├─▶ 캐시 ─▶ DRAM 제어기 ─▶ DRAM    0x8000~0x87FF
                                   ├─▶ AHB→APB3 브리지 ─▶ UART 래퍼   0xF000~0xFFFF
                                   └─▶ 기본 slave (그 밖의 주소 → ERROR)
UART 래퍼 IRQ ─────────────────────────▶ CPU (인터럽트)
```

| 항목 | 규칙 |
|---|---|
| master | CPU 데이터 포트 1개. 명령 포트는 ROM 포트 A와 점대점 |
| 전송 | 단일 전송(`HBURST`=SINGLE), 바이트 전송(`HSIZE`=000). 그 밖의 `HSIZE`는 해당 slave가 2클록 ERROR |
| slave 수락 | `HSEL && HTRANS[1] && HREADY`. `HREADYOUT`·`HRESP`는 데이터 단계 레지스터 상태로만 결정(조합 경로로 `HREADY`에 의존하지 않음) |
| HSEL (M6) | 주소 단계의 `HADDR` 상위 bit로 결정. 기본 slave를 포함해 항상 정확히 하나 |
| 응답 선택 (M6) | `HREADY`=1일 때 선택 결과를 저장하고, 데이터 단계에는 그 slave의 `HRDATA`·`HREADYOUT`·`HRESP`만 사용. reset 직후에는 기본 slave(대기 없는 OKAY) |
| 기본 slave (M6) | 미할당 주소의 NONSEQ는 2클록 ERROR, IDLE은 대기 없는 OKAY. 마지막 오류 주소와 횟수를 디버그 출력(ILA용) |
| 로컬 주소 | 각 slave가 하위 bit를 사용(캐시 `HADDR[10:0]`, ROM `[12:0]`, 브리지 `[11:0]`). 상위 bit 검사는 디코더가 맡으므로 별칭이 없음 |

시험 결과는 [BUS 단위 검증](../04_unit/04_bus/test.md).
