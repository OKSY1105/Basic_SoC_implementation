# SoC BUS 연결 회로 개발 위치

재사용 BUS 모듈은 [공용 BUS 라이브러리](../../../../1_RTL/2_TINY_PROJECT/BUS)에 두고, 이곳에는 SoC별 주소 디코더·UART/RAM 어댑터를 작성한다. [설계 과제](../../02_design/bus.md)를 먼저 정한다.

| 파일 | 내용 | 시험 |
|---|---|---|
| `soc8_ahb_bus.v` | 데이터 포트 AHB-Lite 디코더 + 응답 선택기 + 기본 slave (M6). 주소 맵과 규칙은 파일 머리말과 [설계](../../02_design/bus.md) | [tb_soc8_ahb_bus.sv](../../tb/bus/tb_soc8_ahb_bus.sv) |
