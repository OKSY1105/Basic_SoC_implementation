# CPU 현행 구현 인계

코드 패키지는 [1_RTL/2_TINY_PROJECT/CPU/8bit_CPU](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU), 최상위는 [cpu8_top.v](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/RTL/cpu8_top.v)다. [기존 구현 설명](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/README_PIPELINED.md)과 [기존 검증 기록](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/TEST_STATUS_PIPELINED.md)을 유지한다.

- 단일 코어, R0~R3 각 8bit, X·SP·LR 각 16bit, FLAGS. SP·LR은 v2 1단계 추가다.
- 16bit 명령: opcode[15:10] 6bit, Rd[9:8] 2bit, operand[7:0] 8bit.
- 기존 20개 ISA: HALT, LDI, MOV, LD, ST, LDXL, LDXH, INX, ADD, ADC, SUB, SBC, CMP, AND, JMP, JZ, JC, EI, DI, RETI. EI/DI/RETI는 2026-11-03 인터럽트용으로 추가했다(M11).
- v2 1단계는 PUSH·POP·RET·LSPL·LSPH·PUSH LRx·POP LRx·CALL을 추가해 opcode 31개를 사용한다(CALL은 4칸). 형식·예약 bit·실측 클록은 [명령어 표](isa_table.md), 설계는 [v2 설계안](v2_design.md)을 따른다. CPU VR-015 완료와 펌웨어·통합 VR-016 대기를 구분한다.
- 인터럽트(M11):
  - IRQ 입력 `i_irq` 1개(SoC에서는 UART 래퍼 `o_irq`), 벡터 PC 0x0002
  - 정확한 인터럽트: ID/EX 명령은 버리고 그 PC를 EPC에 저장하며, MEM/WB 명령은 완료한다.
  - 처리 루틴은 전용 레지스터 묶음(R0~R3·X·SP·LR·FLAGS)을 쓴다. 중첩은 없다.
  - 규칙 전문은 [README_PIPELINED 인터럽트 절](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/README_PIPELINED.md), 시험 결과는 [TEST_STATUS](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/TEST_STATUS_PIPELINED.md)에 있다.
- IF / ID·EX / MEM·WB, 데이터 의존성과 메모리 대기에서 stall.
- 분리된 외부 instruction/data 포트. PC는 16bit word 주소, 데이터 주소는 16bit byte 주소.
- 두 포트는 AHB-Lite master다(명령 `HADDR`=17bit `{PC,1'b0}`, 데이터 `HADDR`=X 또는 스택 SP 기반 주소). [CPU AHB 포트 변경안](cpu_ahb_port.md) 기준으로 구현했다(M1). AHB 변경·기존 모듈은 검증·main 병합을 마쳤고 v2 CPU도 VR-015를 통과했다. v2 펌웨어·통합의 검증·병합은 별도다.

| 기본 TB 명령 | 해석 | 결과 |
|---|---|---|
| 080A | opcode 000010, LDI R0,10 | R0=0A |
| 0914 | opcode 000010, LDI R1,20 | R1=14 |
| 2401 | opcode 001001, ADD R0,R1 | R0=1E |
| 0400 | opcode 000001, HALT | halted=1 |

08/09는 명령어 상위 바이트로서 opcode와 Rd가 함께 들어간 값이다. 기본 결과는 regs=0000141E, pc=4, fault=0이다. 기본 TB의 RAM/MMIO 모델은 실제 SoC RAM/UART가 아니다.
