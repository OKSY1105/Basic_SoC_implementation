# BUS 단위 검증 계획 — 미구현

아직 BUS RTL/TB가 없고 이번 실행 대상에 포함하지 않는다.

주소 최초/최종·RAM 경계 밖·미할당·slave 선택 배타성·긴 wait·연속 요청·reset·오류·부작용 1회를 독립 scoreboard로 검사할 계획이다. 포트/주소 맵을 확정한 뒤 TB와 구현을 추가하고 [sources.json](../../sources.json)에 등록한다.
