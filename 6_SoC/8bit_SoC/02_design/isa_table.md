# CPU 명령어 표 — opcode·형식·flag·실행 클록

CPU8의 20개 명령을 한 표로 모은 문서다. 형식은 『Digital Computer Electronics』(Malvino·Brown) SAP-3 부록의 명령어 표(opcode, 길이, 클록 수, 영향 flag)를 따랐다. SAP 컴퓨터와의 전체 비교는 [SAP와 비교](../07_final/sap_comparison.md)에 있다. 동작의 원본은 RTL이다: opcode는 [cpu8_isa.vh](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/RTL/cpu8_isa.vh), 해독은 [cpu8_decoder.v](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/RTL/cpu8_decoder.v), flag는 [cpu8_alu.v](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/RTL/cpu8_alu.v). 규칙 설명은 [README_PIPELINED](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/README_PIPELINED.md)에 있다. 클록 수는 TB로 실측했다(아래 "측정").

## 명령 형식

모든 명령은 16bit 한 word(길이 1)다. PC는 word 주소라 명령마다 1 증가한다.

```text
15          10 9   8 7                            0
+-------------+-----+------------------------------+
| opcode 6bit | r 2 | operand 8bit                 |
+-------------+-----+------------------------------+
```

| 형식 | 필드 | 해당 명령 |
|---|---|---|
| RR | r = Rd, operand[1:0] = Rs, operand[7:2] = 0 | MOV, ADD, ADC, SUB, SBC, CMP, AND |
| R + imm8 | r = Rd, operand = 값 | LDI |
| R + [X] | r = Rd, operand = 0 | LD, ST |
| imm8 | r = 0, operand = 값 | LDXL, LDXH |
| rel8 | r = 0, operand = 부호 있는 변위 | JMP, JZ, JC (목표 = 명령 PC + 1 + rel8) |
| 피연산자 없음 | 하위 10bit = 0 | HALT, INX, EI, DI, RETI |

기계어 = 기준값 + Rd × 0x100 + operand. 예: `ADD R0,R1` = 0x2400 + 0 + 1 = `2401`, `LDI R1,20` = 0x0800 + 0x100 + 0x14 = `0914`. 표에 없는 opcode(0x00, 0x0E~0x13, 0x16, 0x1C~0x3F)와 예약 bit 위반은 불법 명령 fault(코드 1)다.

## 명령어 표

flag 열: Z(0), N(음수), C(덧셈 자리올림, 뺄셈은 1 = 빌림 없음), V(부호 넘침). `●` 결과로 갱신, `0` 0으로, `-` 유지. 클록은 아래 "실행 클록 규칙"의 기본값이고, 메모리 대기가 없는 경우다.

| opcode | 명령 | 기준값 | 형식 | 동작 | Z | N | C | V | 클록 |
|---|---|---|---|---|---|---|---|---|---|
| 01 | HALT | `0400` | 없음 | 앞 명령 완료 후 정지, 뒤 명령 취소 | - | - | - | - | 정지 |
| 02 | LDI Rd,imm8 | `0800` | R + imm8 | Rd ← imm8 | - | - | - | - | 1 |
| 03 | MOV Rd,Rs | `0C00` | RR | Rd ← Rs | - | - | - | - | 1 |
| 04 | LD Rd,[X] | `1000` | R + [X] | Rd ← M[X] (1바이트) | - | - | - | - | 1 + 대기 |
| 05 | ST [X],Rd | `1400` | R + [X] | M[X] ← Rd (1바이트) | - | - | - | - | 1 + 대기 |
| 06 | LDXL imm8 | `1800` | imm8 | X[7:0] ← imm8, X[15:8] 유지 | - | - | - | - | 1 |
| 07 | LDXH imm8 | `1C00` | imm8 | X[15:8] ← imm8, X[7:0] 유지 | - | - | - | - | 1 |
| 08 | INX | `2000` | 없음 | X ← X + 1 (16bit 순환) | - | - | - | - | 1 |
| 09 | ADD Rd,Rs | `2400` | RR | Rd ← Rd + Rs | ● | ● | ● | ● | 1 |
| 0A | ADC Rd,Rs | `2800` | RR | Rd ← Rd + Rs + C | ● | ● | ● | ● | 1 |
| 0B | SUB Rd,Rs | `2C00` | RR | Rd ← Rd − Rs | ● | ● | ● | ● | 1 |
| 1A | SBC Rd,Rs | `6800` | RR | Rd ← Rd − Rs − (1 − C) | ● | ● | ● | ● | 1 |
| 0C | CMP Rd,Rs | `3000` | RR | Rd − Rs의 flag만 반영, Rd 유지 | ● | ● | ● | ● | 1 |
| 0D | AND Rd,Rs | `3400` | RR | Rd ← Rd & Rs | ● | ● | 0 | 0 | 1 |
| 14 | JMP rel8 | `5000` | rel8 | 항상 분기 | - | - | - | - | 2 |
| 15 | JZ rel8 | `5400` | rel8 | Z = 1이면 분기 | - | - | - | - | 2(분기) / 1(통과) |
| 17 | JC rel8 | `5C00` | rel8 | C = 1이면 분기 | - | - | - | - | 2(분기) / 1(통과) |
| 18 | EI | `6000` | 없음 | 인터럽트 허용(IE = 1), 다음 명령부터 적용 | - | - | - | - | 1 |
| 19 | DI | `6400` | 없음 | 인터럽트 금지(IE = 0) | - | - | - | - | 1 |
| 1B | RETI | `6C00` | 없음 | PC ← EPC, 레지스터 묶음 0, IE = 1. 처리 루틴 밖에서는 불법 명령 | - | - | - | - | 미측정 |

- 산술 결과는 8bit다. C와 ADC·SBC로 여러 바이트 계산을 잇는다. CMP 뒤 C = 1이면 Rd ≥ Rs(부호 없음)다.
- 곱셈·나눗셈 명령은 없다. 펌웨어가 반복으로 계산한다([계산기 규약](calculator.md)).
- 인터럽트 진입: IRQ 요청부터 벡터(0x0002) 첫 명령까지 시험 조건(메모리 대기 포함)에서 최대 6클록이다. 처리 루틴은 별도 레지스터 묶음을 쓰므로 저장·복원 명령이 없다(README_PIPELINED 인터럽트 절).

## 실행 클록 규칙

파이프라인은 IF / ID·EX / MEM·WB 3단이고 forwarding이 없다. 그래서 클록 수는 명령 자체보다 앞 명령과의 관계로 정해진다.

| 규칙 | 추가 클록 | 근거(측정 사례) |
|---|---|---|
| 기본: 모든 명령은 매 클록 하나씩 발행 | 0 (1클록/명령) | `ldi`·`mov`·`cmp`·`ld`·`st`·`ei`·`di` |
| 바로 앞 명령이 쓴 값(R0~R3, FLAGS, X)을 읽음 | +1 | `add_dep1`, `mov_dep`, `adc_flags`·`sbc_flags`(C flag), `ld_use`(읽은 값 사용), `st_after_write`, `ldxl`·`inx`·`inx_ld`(X), `cmp_jz`(Z flag) |
| 두 명령 이상 앞에서 쓴 값을 읽음 | 0 | `add_dep2`·`sub_dep2`·`and_dep2` |
| 분기함(JMP, 조건 참인 JZ·JC) | +1 (이미 인출한 다음 명령을 버림) | `jmp`·`jz_taken`·`jc_taken` |
| 분기 안 함 | 0 | `jz_not`·`jc_not` |
| 메모리 대기 | slave가 `HREADY`를 낮춘 클록 수만큼 | 아래 표 |

- ADD·SUB·AND·ADC·SBC·CMP는 Rd도 읽는다. 그래서 `ADD R0,R1`을 연달아 쓰면 매번 앞 결과를 읽어 2클록씩 걸린다. 결과를 두 명령 뒤에 쓰도록 순서를 바꾸면 1클록이 된다.
- LDXL·LDXH도 X 전체를 읽고 쓰므로(나머지 바이트 유지) 바로 앞의 X 변경에 의존한다. LDXH는 LDXL과 같은 경로이고 측정은 LDXL로 했다.
- CMP 바로 뒤 조건 분기는 flag 의존(+1)과 분기(+1)가 겹쳐 두 명령에 4클록이다(`cmp_jz`).

SoC에서 메모리 대기(명령 포트·데이터 포트):

| 대상 | 대기 | 근거 |
|---|---|---|
| ROM (명령, 0x0000~) | 0 | [CPU AHB 포트](cpu_ahb_port.md) "ROM 포트 A는 대기 없는 AHB-Lite slave" |
| RAM, 캐시 hit | 0 | [캐시 README](../../../1_RTL/2_TINY_PROJECT/Cache/README.md) "hit 지연: 데이터 단계 첫 클록에 완료" |
| RAM, 캐시 miss | 약 94클록(줄 읽기), dirty면 줄 쓰기를 더해 약 200클록. 짝 시험 평균 143·최대 207클록 | [RAM](ram.md) 제어기 줄 단위 포트 행 |
| UART 레지스터(APB) | 최소 2클록 | [BUS](bus.md) AHB→APB3 브리지 행 |

## 측정

도구: [measure_cpu8_cycles.py](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/TOOLS/measure_cpu8_cycles.py). 공통 준비 명령 뒤에 짧은 명령 묶음을 N번(16) 반복하고 HALT로 끝낸다. 같은 묶음을 2N번 반복한 실행과의 차이를 N으로 나눠 묶음 하나의 정상 상태 클록을 구한다. 준비·시작·HALT 비용은 빼기에서 지워진다. 메모리는 TB의 대기 없는 모델(ROM·캐시 hit과 같은 조건)이다. 모든 프로그램의 마지막 상태(PC·레지스터·X·FLAGS)를 [run_cpu8_tests.py](../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/TOOLS/run_cpu8_tests.py)의 ISA 모델과 비교한다.

```sh
cd 1_RTL/2_TINY_PROJECT/CPU/8bit_CPU
python3 TOOLS/measure_cpu8_cycles.py --vivado-bin /home/sean/Vivado/2024.2/bin --build-dir /tmp/claude_runs/cpu_cycles
```

결과(2026-11-09, WSL Vivado 2024.2 XSim, 프로그램 50개, ISA 모델과 상태 일치, `CPU8_CYCLES_PASS cases=25 programs=50`):

| 사례 | 반복한 묶음 | 묶음당 클록 | 명령당 클록 | 묶음당 stall |
|---|---|---|---|---|
| `ldi` | LDI R0,5 | 1 | 1.0 | 0 |
| `mov` | MOV R1,R2 | 1 | 1.0 | 0 |
| `mov_dep` | MOV R1,R2 / MOV R2,R1 | 4 | 2.0 | 2 |
| `add_dep1` | ADD R0,R1 | 2 | 2.0 | 1 |
| `add_dep2` | ADD R0,R1 / ADD R2,R3 | 2 | 1.0 | 0 |
| `sub_dep2` | SUB R0,R1 / SUB R2,R3 | 2 | 1.0 | 0 |
| `and_dep2` | AND R0,R1 / AND R2,R3 | 2 | 1.0 | 0 |
| `adc_flags` | ADC R0,R1 / ADC R2,R3 | 4 | 2.0 | 2 |
| `sbc_flags` | SBC R0,R1 / SBC R2,R3 | 4 | 2.0 | 2 |
| `cmp` | CMP R0,R1 | 1 | 1.0 | 0 |
| `ld` | LD R0,[X] | 1 | 1.0 | 0 |
| `ld_use` | LD R0,[X] / ADD R1,R0 | 3 | 1.5 | 1 |
| `st` | ST [X],R0 | 1 | 1.0 | 0 |
| `st_after_write` | LDI R0,5 / ST [X],R0 | 3 | 1.5 | 1 |
| `ldxl` | LDXL 16 | 2 | 2.0 | 1 |
| `inx` | INX | 2 | 2.0 | 1 |
| `inx_ld` | INX / LD R0,[X] | 3 | 1.5 | 1 |
| `jmp` | JMP 0 (다음 명령으로 분기) | 2 | 2.0 | 0 |
| `jz_not` | JZ 0 (Z = 0) | 1 | 1.0 | 0 |
| `jz_taken` | JZ 0 (Z = 1) | 2 | 2.0 | 0 |
| `jc_not` | JC 0 (C = 0) | 1 | 1.0 | 0 |
| `jc_taken` | JC 0 (C = 1) | 2 | 2.0 | 0 |
| `cmp_jz` | CMP R0,R0 / JZ 0 | 4 | 2.0 | 1 |
| `ei` | EI | 1 | 1.0 | 0 |
| `di` | DI | 1 | 1.0 | 0 |

- 분기의 추가 클록은 stall이 아니라 버린 인출로 생기므로 stall 열은 0이다.
- 측정하지 않은 것: RETI(처리 루틴 안에서만 실행됨), HALT(정지), 계산기 펌웨어 전체의 평균 CPI(SoC 통합 TB가 완료 명령 수를 출력하지 않는다), 메모리 대기가 있는 경우의 실제 분포.
