# BUS 공용 모듈 개발 위치

재사용 가능한 BUS 모듈은 이곳에서 개발하고, 6_SoC/8bit_SoC는 해당 원본과 SoC별 주소 디코더·어댑터를 연결한다. 규격·포트·검증 기준은 SoC의 02_design/bus.md에서 먼저 정한다.

## AHB-Lite 시험 도구 (단일 전송)

| 파일 | 역할 |
|---|---|
| `ahb_lite_master_bfm.sv` | master 모델. `push()`로 넣은 전송을 파이프라인으로 실행(현재 데이터 단계 중 다음 주소 단계)하고, `HREADY`=0 동안 주소 단계와 `HWDATA`를 유지한다. 완료마다 `results[]`에 1건을 기록한다. IDLE 주소 단계에는 무작위 `HADDR`을 내고, `cancel_on_error`=1이면 ERROR 둘째 클록에 대기 중인 주소 단계를 IDLE로 바꾼 뒤 그 전송을 다시 낸다 |
| `ahb_lite_slave_model.sv` | slave 모델. 전송마다 `MIN_WAIT`~`MAX_WAIT` 무작위 대기, `HADDR[3:0]`=F는 2클록 ERROR, 읽기 데이터는 `ID`에 따른 주소 함수다. 데이터 단계를 갖지 않을 때는 출력을 무작위로 낸다(`JUNK`). 완료한 전송을 `log[]`에 기록한다 |
| `ahb_lite_slave_checker.sv` | slave 응답 규칙 SVA(`AHB_LITE_SVA` 정의 시): IDLE은 대기 없는 OKAY, ERROR는 2클록, OKAY 대기 상한. 위반 시 `FAIL` 줄을 출력하고 `fails`를 증가시킨다. 버스 전체를 master 쪽에서 볼 때는 `hsel`=1, `hreadyout`=버스 `HREADY`로 연결한다 |

사용 예: [8bit SoC AHB 버스 TB](../../../6_SoC/8bit_SoC/tb/bus/tb_soc8_ahb_bus.sv). 예정: AHB→APB3 브리지, 리셋 동기화기, APB 규칙 검사기.
