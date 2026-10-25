# CPU8 — 8bit CPU

최상위 모듈은 **`RTL/cpu8_top.v`의 `cpu8_top`**이다.

- 단일 코어, 쓰기 가능한 8bit 범용 레지스터 R0~R3.
- 16bit 고정 명령, 17개 ISA.
- IF / ID·EX / MEM·WB 3단계 파이프라인, 의존성 stall.
- 프로그램 ROM과 데이터 RAM/UART를 연결하는 분리 외부 포트.

[전체 설계·ISA·실행 방법](README_PIPELINED.md)과 [검증 결과](TEST_STATUS_PIPELINED.md)를 참고한다.

```sh
python3 TOOLS/run_cpu8_tests.py --simulator iverilog
yosys -s TOOLS/check_cpu8.ys
```

이전 MIPS형 CPU 코드와 관련 테스트·실행 파일은 사용자 요청에 따라 삭제했다.
ROM/BRAM·UART·계산기 펌웨어·STM32 LCD 통합 및 FPGA 타이밍·실물 검증은 후속 작업이다.
