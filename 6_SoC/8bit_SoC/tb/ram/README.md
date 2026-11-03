# DRAM 단위 TB 참조

원본은 [1_RTL 공용 라이브러리](../../../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/tb_dram_controller.v)에 있다. 이 SoC는 원본을 직접 읽으며 같은 모듈의 사본이나 심볼릭 링크를 이곳에 두지 않는다.

SoC용 연결 회로·제약·통합 TB를 추가할 때만 이 폴더에 새 파일을 작성한다. 단위 실행은 sources.json, 프로젝트 생성은 scripts/create_vivado.tcl의 공용 모듈 경로를 사용한다.

| 파일 | 대상 | 기대 출력 |
|---|---|---|
| `tb_cache_dram.sv` | SoC RAM 경로 짝 시험: AHB master 모델 → [캐시](../../../../1_RTL/2_TINY_PROJECT/Cache/cache.v) → [DRAM 제어기 줄 포트](../../../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/dram_controller.v) → 행동 모델 | `CACHE_DRAM_PASS` |
