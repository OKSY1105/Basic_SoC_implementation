# CPU 현행 구현 인계

코드 패키지는 [rtl/cpu/8bit_CPU](../rtl/cpu/8bit_CPU), 최상위는 [cpu8_top.v](../rtl/cpu/8bit_CPU/RTL/cpu8_top.v)다. [기존 구현 설명](../rtl/cpu/8bit_CPU/README_PIPELINED.md)과 [기존 검증 기록](../rtl/cpu/8bit_CPU/TEST_STATUS_PIPELINED.md)을 유지한다.

- 단일 코어, R0~R3 각 8bit, X 16bit, FLAGS.
- 16bit 명령: opcode[15:10] 6bit, Rd[9:8] 2bit, operand[7:0] 8bit.
- 17개 ISA: HALT, LDI, MOV, LD, ST, LDXL, LDXH, INX, ADD, ADC, SUB, SBC, CMP, AND, JMP, JZ, JC.
- IF / ID·EX / MEM·WB, 데이터 의존성과 메모리 대기에서 stall.
- 분리된 외부 instruction/data 포트. 명령 주소는 16bit word 주소, 데이터 주소는 16bit byte 주소.

| 기본 TB 명령 | 해석 | 결과 |
|---|---|---|
| 080A | opcode 000010, LDI R0,10 | R0=0A |
| 0914 | opcode 000010, LDI R1,20 | R1=14 |
| 2401 | opcode 001001, ADD R0,R1 | R0=1E |
| 0400 | opcode 000001, HALT | halted=1 |

08/09는 명령어 상위 바이트로서 opcode와 Rd가 함께 들어간 값이다. 기본 결과는 regs=0000141E, pc=4, fault=0이다. 기본 TB의 RAM/MMIO 모델은 실제 SoC RAM/UART가 아니다.
