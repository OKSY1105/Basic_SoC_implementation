# DRAM 행동 모델 참조

원본은 [1_RTL 공용 라이브러리](../../../../1_RTL/2_TINY_PROJECT/DRAM/dram.v)에 있다. 이 SoC는 원본을 직접 읽으며 같은 모듈의 사본이나 심볼릭 링크를 이곳에 두지 않는다.

SoC용 연결 회로·제약·통합 TB를 추가할 때만 이 폴더에 새 파일을 작성한다.

| 파일 | 역할 |
|---|---|
| `soc8_dram_model.v` | `soc8_top`의 DRAM 핀(제어기 core의 분리 DQ/DQS)에 동작 모델 `dram.v`를 붙이는 시뮬레이션 전용 연결 회로. 3상태 구동은 core의 출력 enable을 그대로 따른다(`dram_controller` 래퍼와 같은 방식). 보드에서는 BRAM 기반 합성 가능 모델(M4)이 이 자리에 들어간다 | 단위 실행은 sources.json, 프로젝트 생성은 scripts/create_vivado.tcl의 공용 모듈 경로를 사용한다.
