# 기존 CPU 단독 Vivado 프로젝트 참조

원본은 [1_RTL 공용 라이브러리](../../../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/8bit_cpu_sim/8bit_cpu_sim.xpr)에 있다. 이 SoC는 원본을 직접 읽으며 같은 모듈의 사본이나 심볼릭 링크를 이곳에 두지 않는다.

SoC용 연결 회로·제약·통합 TB를 추가할 때만 이 폴더에 새 파일을 작성한다. 단위 실행은 sources.json, 프로젝트 생성은 scripts/create_vivado.tcl의 공용 모듈 경로를 사용한다.
