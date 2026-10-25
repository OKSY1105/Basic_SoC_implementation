# CPU8: 4개 레지스터·3단계 파이프라인 8bit CPU

현재 새 CPU의 최상위는 **`RTL/cpu8_top.v`의 `cpu8_top`**이다.
기존 `CPU/`의 `cpu_top`과 `TB/tb_cpu_top.v`는 이전 MIPS형 CPU를 참고/회귀검증용으로 보존했다.
기존 README.md는 그 이전 CPU 설명이다. 두 ISA와 포트는 호환되지 않는다.

## 구현 범위

- 단일 코어, 모두 읽고 쓸 수 있는 R0~R3 4개(각각 8bit). R0도 일반 레지스터다.
- IF / ID·EX / MEM·WB 3단계, 순차 완료, forwarding 없이 GPR/FLAGS/X 의존성을 stall로 처리.
- 16bit 고정 명령, opcode [15:10] / r [9:8] / operand [7:0].
- 16bit 프로그램 PC는 **명령 word** 주소, 16bit X와 데이터 포트는 **byte** 주소.
- 아래 17개 명령을 구현. MUL/DIV는 프로그램 반복으로 구성하며 전용 opcode는 없다.
- CPU 코어에는 ROM·RAM·UART를 내장하지 않는다. 프로그램 ROM과 데이터 RAM/MMIO는 분리된 외부 포트에 연결한다.
- 첫 시스템 데이터 RAM은 2KiB(2,048×8bit)로 선정했다. 상위 모듈에서 범위를 디코드한다. CPU의 16bit 주소가 64KiB RAM 내장을 의미하지 않는다.
- PC는 숫자·연산 요청만 UART로 전송하고, FPGA ROM의 CPU 프로그램이 이를 처리하는 시스템 구성을 따른다.
  완전한 UART 파서/계산기 펌웨어·UART IP·STM32 LCD 드라이버는 이번 CPU 코어에 포함하지 않는다.

## 파일

| 파일 | 역할 |
|---|---|
| `RTL/cpu8_top.v` | 단계 경계·인출 PC·완료 PC·interlock·메모리/HALT/fault 제어 |
| `RTL/cpu8_decoder.v` | 17개 명령·예약 비트·읽기/쓰기 대상 해독 |
| `RTL/cpu8_regfile.v` | 4×8bit 2R1W, R0 쓰기 가능 |
| `RTL/cpu8_alu.v` | ADD/ADC·SUB/SBC/CMP·AND, Z/N/C/V |
| `RTL/cpu8_isa.vh` | opcode 상수 |
| `TB/tb_cpu8_top.sv` | 여러 프로그램·메모리 지연·부작용·retirement trace |
| `TB/tb_cpu8_alu.sv` | 독립 정수 범위 기준 786,432개 산술/플래그 조합 |
| `TB/tb_cpu8_reset.sv` | 메모리 대기 중 리셋·이전 명령 폐기·재시작 |
| `TOOLS/cpu8_asm.py` | 레이블/rel8·.org·.word를 지원하는 작은 어셈블러 |
| `TOOLS/run_cpu8_tests.py` | 독립 ISA 모델과 실제 RTL 명령 완료 상태/메모리 접근 비교 |
| `TOOLS/check_cpu8.ys` | 일반 논리 합성·드라이버 검사·래치 없음 확인 |
| `TOOLS/synth_cpu8.tcl` | 대표 Zynq-7020 부품의 out-of-context 합성 |
| `PROGRAMS/first_add.asm` / `first_add.mem` | 10+20=30 첫 동작 프로그램 |

## ISA

```text
15          10 9   8 7                            0
+-------------+-----+------------------------------+
| opcode 6bit | r 2 | operand 8bit                 |
+-------------+-----+------------------------------+
```

| Opcode | 명령 | 의미 |
|---|---|---|
| 01 | HALT | 앞 명령 완료 후 정지, 이후 명령 취소 |
| 02 | LDI Rd,imm8 | Rd에 비트 패턴 저장, FLAGS 유지 |
| 03 | MOV Rd,Rs | 값 복사, FLAGS 유지 |
| 04 | LD Rd,[X] | 한 바이트 읽기, FLAGS 유지 |
| 05 | ST [X],Rd | 한 바이트 쓰기, FLAGS 유지 |
| 06 | LDXL imm8 | X 하위 바이트 변경, 상위 보존 |
| 07 | LDXH imm8 | X 상위 바이트 변경, 하위 보존 |
| 08 | INX | X를 1 증가, 16bit 순환 |
| 09 | ADD Rd,Rs | Rd=Rd+Rs |
| 0A | ADC Rd,Rs | Rd=Rd+Rs+이전 C |
| 0B | SUB Rd,Rs | Rd=Rd-Rs |
| 0C | CMP Rd,Rs | 뺄셈 FLAGS만 변경, GPR 유지 |
| 0D | AND Rd,Rs | Rd=Rd&Rs, Z/N 갱신·C/V=0 |
| 14 | JMP rel8 | PC=명령 PC+1+signed rel8 |
| 15 | JZ rel8 | Z=1이면 분기 |
| 17 | JC rel8 | C=1이면 분기 |
| 1A | SBC Rd,Rs | Rd=Rd-Rs-(1-이전 C) |

- RR 형식은 r=Rd, operand[1:0]=Rs이고 operand[7:2]=0.
- LD/ST는 operand=0. LDXL/LDXH와 분기는 r=0. HALT/INX는 하위 10bit=0.
- NOP을 포함해 위 목록 외 opcode와 예약 비트 위반은 ILLEGAL_INSTRUCTION fault다.
- `o_flags[3:0]={Z,N,C,V}`. 뺄셈 C=1은 **빌림 없음**이다.
- ADD/ADC·SUB/SBC·CMP는 Z/N/C/V를 갱신한다. 결과는 8bit, carry/borrow로 여러 바이트 계산을 연결한다.
- 주소·분기 계산은 16bit에서 순환한다. 실제 매핑 여부는 외부 메모리의 오류 응답으로 판정한다.

## 외부 메모리 포트

| 방향 | 신호 | 단위 |
|---|---|---|
| 출력 | `o_i_req, o_i_addr[15:0]` | 16bit 명령 word 주소 |
| 입력 | `i_i_ready, i_i_data[15:0], i_i_error` | 명령 완료·명령 데이터·오류 |
| 출력 | `o_d_req, o_d_write, o_d_addr[15:0], o_d_wdata[7:0]` | byte 주소·쓰기 값 |
| 입력 | `i_d_ready, i_d_rdata[7:0], i_d_error` | 데이터 완료·읽기 값·오류 |

**이번 구현은 기존 CPU의 req/ready 형태를 참고한 완료 handshake다.** 각 포트의 `req && ready` 상승 에지에서
요청 수락과 완료가 함께 발생한다. 이전 설계 문서의 별도 request/response 채널 제안과 신호를 그대로 혼용하지 않는다.
외부 동기식 RAM/ROM 래퍼는 읽기 데이터가 준비된 에지에 ready를 올리면 된다.

- ready=0 동안 데이터 요청의 주소·방향·쓰기 값은 유지한다. ready가 참인 에지에서 한 번만 부작용을 발생시킨다.
- 오류가 참인 완료에서는 메모리 래퍼가 RAM/UART 쓰기·FIFO pop/push를 억제해야 한다.
- 인출 요청은 리셋·최선행 오류/HALT에서 취소할 수 있다. 명령 읽기는 부작용 없는 접근이어야 한다.
- reset은 아직 수락되지 않은 데이터 요청도 취소한다. 이미 반영한 외부 쓰기는 되돌리지 않는다.
- instruction/data 포트의 구현 지연에 따라 처리율은 달라진다. 모든 명령이 고정 3클록이라는 규약은 아니다.

## 완료·정지·리셋

- active-low **동기식** `i_rst_n`. 보드 상위에서 리셋 해제를 해당 클록에 동기화한다.
- 리셋 시 GPR·X·FLAGS·PC·유효 단계·halt/fault를 지운다. 외부 RAM 전체를 지우는 신호가 아니다.
- 결과는 유효한 MEM/WB에서 한 번만 반영한다. 대기 중 앞 WB는 계속 완료하고, RAW는 그 다음 클록의 최신 값으로 재개한다.
- HALT를 ID에서 발행하면 후속 인출을 막고, HALT가 최선행 WB에서 완료될 때 halted를 올린다.
- `o_pc`는 완료 기준 다음 word 주소다. fault 시 실패 명령의 word 주소를 유지한다.
- `o_fault_code`: 1=불법 명령, 2=명령 접근 오류, 3=데이터 접근 오류. 정상 HALT는 fault=0.
- 최선행 데이터 오류가 뒤 명령의 분기/정지보다 우선한다. 오류 명령과 후속 명령은 GPR/FLAGS/X를 변경하지 않는다.
- `o_retire_*`는 시험/디버그용 완료 추적, `o_stage_valid={MEM/WB,ID/EX,IF요청}`, `o_stall`은 ID 진행 보류다.

## 실행

Linux/WSL에서 Icarus Verilog와 Python 3이 준비된 경우:

```sh
python3 TOOLS/run_cpu8_tests.py --simulator iverilog
python3 TOOLS/cpu8_asm.py PROGRAMS/first_add.asm -o PROGRAMS/first_add.mem
```

Vivado 환경을 설정한 경우:

```sh
python3 TOOLS/run_cpu8_tests.py --simulator xsim
vivado -mode batch -source TOOLS/synth_cpu8.tcl
```

Windows에서는 `--vivado-bin C:/Xilinx/Vivado/2024.2/bin`을 지정할 수 있다.
`--build-dir`로 시험 출력 경로를 변경할 수 있다. 생성물은 Git에서 제외한다.
도구 실행 환경의 실패와 RTL의 기능 통과 여부는 `TEST_STATUS_PIPELINED.md`에 구분해 기록한다.
합성 예제의 기본 `xc7z020clg400-1`은 후보 칩 기준이며 최종 보드·패키지·핀·목표 클록 확정이 아니다.

## 기존 블록 참고

기존 `CPU/DU/alu.v`의 9bit 산술/carry/overflow 방식과 `irf.v`의 2R1W 구조,
`CPU/CU/instruction_decoder.v`의 기본 제어 신호 구성, `CPU/DU/pc.v`·`ir.v`의 enable/hold 개념을 참고했다.
새 ISA·GPR 수·분리 포트·파이프라인에 맞는 제어는 새 `cpu8_*` 모듈로 작성했다.
기존 MIPS 코드의 8개 레지스터·R0 상수·공유 바이트 버스·다중 사이클 동작을 새 코어의 명세로 가져오지 않았다.

첫 ROM 프로그램의 `080A / 0914 / 2401 / 0400`은 고정 입력 설명/단위 시험이다.
전체 계산기에서는 ROM 프로그램이 UART 데이터를 읽어 변환하여 계산해야 한다.
