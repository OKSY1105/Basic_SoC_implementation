# BUS 설계 과제 — 미구현

재사용 BUS 원본 개발 위치는 [1_RTL BUS](../../../1_RTL/2_TINY_PROJECT/BUS)이며, SoC별 주소 디코더/어댑터는 [rtl/bus](../rtl/bus), 통합 시험은 [tb/bus](../tb/bus)에 둔다. 이번에 BUS RTL이나 전체 SoC 연결이 생성된 것은 아니다.

## 결정 — 2026-10-30

| 항목 | 내용 | 상태 |
|---|---|---|
| 메모리 구조 | 수정 하버드: CPU 코어의 명령/데이터 포트는 분리 유지, 시스템은 ROM·RAM·UART를 단일 주소 맵에 배치 | 사용자 확정 |
| 버스 | 직접 정의한 req/ready 대신 표준 AMBA 프로토콜 | 사용자 확정 |
| 프로토콜 조합 | AHB-Lite(ROM·RAM) + AHB-to-APB 브리지 + APB(UART) | 추천안, 진행 기준 |
| 단계 | 1차: 명령 포트→ROM 직결, 데이터 포트→AHB-Lite master 어댑터(단일 master). 2차: 명령 포트도 AHB master로 연결하고 중재기 추가 | 추천안, 진행 기준 |
| CPU 코어 | RTL·ISA·req/ready 포트 무변경, AHB 변환은 SoC `rtl/bus`의 어댑터가 담당 | 추천안, 진행 기준 |

아래 표의 각 항목은 이 결정을 기준으로 AHB-Lite/APB 신호(HTRANS·HREADY·HRESP, PSEL·PENABLE·PREADY·PSLVERR)로 구체화한다.

| 정할 항목 | 필요한 동작/시험 |
|---|---|
| 주소 디코딩 | 16bit byte 주소에서 RAM/UART 선택, 미할당 접근 오류 |
| 로컬 주소 변환 | RAM 영역 확인 뒤 11bit로 변환; 단순 하위 bit 절단 alias 금지 |
| 대기 | 요청·주소·쓰기 데이터 보관, slave 완료 전 CPU stall |
| 응답 | 선택한 slave의 ready/rdata/error만 반영 |
| 부작용 | 한 완료당 UART pop/push·메모리 쓰기 각각 1회 |
| reset | 진행 중 취소/이미 반영된 쓰기/drain 규칙 합의 |
| 명령 연결 | 현행 분리 ROM 인출 유지 또는 공유 메모리 변경은 별도 결정 |

단위 시험은 최초/최종 주소·미할당·back-to-back·긴 wait·reset 중 접근·중복 완료·비선택 slave의 가짜 ready를 포함한다. 통합 전 포트 시간표와 기대 결과를 문서화한다.
