# BUS 설계 과제 — 미구현

재사용 BUS 원본 개발 위치는 [1_RTL BUS](../../../1_RTL/2_TINY_PROJECT/BUS)이며, SoC별 주소 디코더/어댑터는 [rtl/bus](../rtl/bus), 통합 시험은 [tb/bus](../tb/bus)에 둔다. 이번에 BUS RTL이나 전체 SoC 연결이 생성된 것은 아니다.

첫 연결 후보는 CPU의 기존 req/ready 데이터 포트를 유지하는 단일 master 구조다. APB/AHB/AXI 채택 여부는 별도 결정이며 폴더 정리만으로 확정하지 않는다.

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
