# CPU8 — 8bit CPU

최상위 모듈은 **`RTL/cpu8_top.v`의 `cpu8_top`**이다.

- 단일 코어, 쓰기 가능한 8bit 범용 레지스터 R0~R3.
- 16bit 고정 명령, 17개 ISA.
- IF / ID·EX / MEM·WB 3단계 파이프라인, 의존성 stall.
- 프로그램 ROM과 데이터 RAM/UART를 연결하는 분리 외부 포트.

[전체 설계·ISA·실행 방법](README_PIPELINED.md)과 [검증 결과](TEST_STATUS_PIPELINED.md)를 참고한다.

## Vivado에서 바로 실행

1. Design Sources에 `RTL/`의 .v 파일4개와 `cpu8_isa.vh`를 추가한다.
2. Simulation Sources에 `TB/tb_cpu8_top.sv`를 추가하고 simulation top을 `tb_cpu8_top`으로 설정한다.
3. Run Simulation → Run Behavioral Simulation을 실행한다. 기본 실행 시간이0이면 Run All을 누른다.

TB가 클록·리셋·시험 ROM을 자동 생성하고 `LDI R0,10 / LDI R1,20 / ADD R0,R1 / HALT`를 실행한다.
외부 입력·명령어 전송·CASES 옵션·.mem 파일·Python 실행 없이 기본 시험이 동작한다.
이전에 설정했던 CASES 옵션이 남아 있다면 지워 기본 시험을 선택한다.

정상 결과는 `CPU8_DEMO_PASS: 10 + 20 = 30`, 파형은 `regs=0000141E`·`pc=4`·`halted=1`·`fault=0`이다.

## 전체 자동 회귀

```sh
python3 TOOLS/run_cpu8_tests.py --simulator iverilog
yosys -s TOOLS/check_cpu8.ys
```

이전 MIPS형 CPU 코드와 관련 테스트·실행 파일은 사용자 요청에 따라 삭제했다.
ROM/BRAM·UART·계산기 펌웨어·STM32 LCD 통합 및 FPGA 타이밍·실물 검증은 후속 작업이다.
