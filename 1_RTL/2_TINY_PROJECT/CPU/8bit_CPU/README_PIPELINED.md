# CPU8: 4개 레지스터·3단계 파이프라인 8bit CPU

현재 새 CPU의 최상위는 **`RTL/cpu8_top.v`의 `cpu8_top`**이다.
이 폴더는 새 CPU8 코어와 검증 환경을 담는다. 이전 MIPS형 CPU RTL·테스트벤치·실행 스크립트는 2026-10-25 사용자 요청으로 삭제했다.
현재 설계의 RTL은 `RTL/`, 테스트벤치는 `TB/tb_cpu8_*.sv`에 있다.

## 구현 범위

- 단일 코어, 모두 읽고 쓸 수 있는 R0~R3 4개(각각 8bit). R0도 일반 레지스터다.
- IF / ID·EX / MEM·WB 3단계, 순차 완료, forwarding 없이 GPR/FLAGS/X 의존성을 stall로 처리.
- 16bit 고정 명령, opcode [15:10] / r [9:8] / operand [7:0].
- 16bit 프로그램 PC는 **명령 word** 주소, 16bit X와 데이터 포트는 **byte** 주소. 명령 포트의 AHB 주소는 byte 단위 `{PC,1'b0}`(17bit)이다.
- 아래 20개 명령을 구현(17개 + 2026-11-03 추가한 인터럽트 제어 EI/DI/RETI). MUL/DIV는 프로그램 반복으로 구성하며 전용 opcode는 없다.
- IRQ 입력 1개의 정확한 인터럽트(precise interrupt)를 지원한다. 처리 루틴은 별도 레지스터 묶음을 쓴다(아래 "인터럽트" 절).
- CPU 코어에는 ROM·RAM·UART를 내장하지 않는다. 프로그램 ROM과 데이터 RAM/MMIO는 분리된 외부 포트에 연결한다.
- 첫 시스템 데이터 RAM은 2KiB(2,048×8bit)로 선정했다. 상위 모듈에서 범위를 디코드한다. CPU의 16bit 주소가 64KiB RAM 내장을 의미하지 않는다.
- PC는 숫자·연산 요청만 UART로 전송하고, FPGA ROM의 CPU 프로그램이 이를 처리하는 시스템 구성을 따른다.
  완전한 UART 파서/계산기 펌웨어·UART IP·STM32 LCD 드라이버는 이번 CPU 코어에 포함하지 않는다.

## 파일

| 파일 | 역할 |
|---|---|
| `RTL/cpu8_top.v` | 단계 경계·인출 PC·완료 PC·interlock·메모리/HALT/fault·인터럽트 제어 |
| `RTL/cpu8_decoder.v` | 20개 명령·예약 비트·읽기/쓰기 대상 해독 |
| `RTL/cpu8_regfile.v` | 4×8bit 2R1W × 2묶음(프로그램/인터럽트 처리), R0 쓰기 가능 |
| `RTL/cpu8_alu.v` | ADD/ADC·SUB/SBC/CMP·AND, Z/N/C/V |
| `RTL/cpu8_isa.vh` | opcode 상수 |
| `TB/tb_cpu8_top.sv` | 기본 내장 덧셈 데모 + 선택적 외부 회귀·메모리 지연·retirement trace |
| `TB/tb_cpu8_alu.sv` | 독립 정수 범위 기준 786,432개 산술/플래그 조합 |
| `TB/tb_cpu8_reset.sv` | 메모리 대기 중 리셋·이전 명령 폐기·재시작 |
| `TB/cpu8_ahb_checker.sv` | 두 AHB-Lite master 포트의 규칙 SVA(`CPU8_SVA`) |
| `TB/cpu8_irq_checker.sv` | 인터럽트 진입·복귀·레지스터 묶음 규칙 SVA(`CPU8_SVA`) |
| `TOOLS/cpu8_asm.py` | 레이블/rel8·.org·.word를 지원하는 작은 어셈블러. 2026-11-04에 `.equ NAME, value`(이름 상수, 쓰기 전에 정의)와 문자 상수 `'c'`(`,` `;` `:`는 줄 해석에 쓰이므로 `.equ`로 적는다)를 추가했다. 기존 프로그램의 기계어는 같다(회귀 시험이 만드는 88개 프로그램과 저장소의 `.asm` 5개 대조) |
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
| 18 | EI | 인터럽트 허용(IE=1). 발행 시점에 반영되어 다음 명령부터 적용 |
| 19 | DI | 인터럽트 금지(IE=0). 발행 시점에 반영 |
| 1B | RETI | 처리 루틴에서 복귀: PC=EPC, 레지스터 묶음 0, IE=1. 처리 루틴 밖에서는 불법 명령 |

- RR 형식은 r=Rd, operand[1:0]=Rs이고 operand[7:2]=0.
- LD/ST는 operand=0. LDXL/LDXH와 분기는 r=0. HALT/INX/EI/DI/RETI는 하위 10bit=0.
- NOP을 포함해 위 목록 외 opcode와 예약 비트 위반은 ILLEGAL_INSTRUCTION fault다.
- `o_flags[3:0]={Z,N,C,V}`. 뺄셈 C=1은 **빌림 없음**이다.
- ADD/ADC·SUB/SBC·CMP는 Z/N/C/V를 갱신한다. 결과는 8bit, carry/borrow로 여러 바이트 계산을 연결한다.
- 주소·분기 계산은 16bit에서 순환한다. 실제 매핑 여부는 외부 메모리의 오류 응답으로 판정한다.

## 외부 메모리 포트

두 포트 모두 **AMBA AHB-Lite master**다(2026-11-03 변경, 이전 `req && ready` 방식 대체).
단일 전송만 사용한다(`HTRANS` IDLE/NONSEQ, `HBURST` SINGLE). 경로·시간표·규칙의 원문은
[CPU AHB 포트 변경안](../../../../6_SoC/8bit_SoC/02_design/cpu_ahb_port.md)이다.

| 포트 | 출력 | 입력 | 고정값 |
|---|---|---|---|
| 명령 | `o_i_haddr[16:0]`(=`{PC,1'b0}`), `o_i_htrans[1:0]` | `i_i_hrdata[15:0]`, `i_i_hready`, `i_i_hresp` | `HSIZE`=001, `HPROT`=0010, `HWRITE`=0 |
| 데이터 | `o_d_haddr[15:0]`(=X), `o_d_htrans[1:0]`, `o_d_hwrite`, `o_d_hwdata[7:0]` | `i_d_hrdata[7:0]`, `i_d_hready`, `i_d_hresp` | `HSIZE`=000, `HPROT`=0011 |

`HBURST`=000, `HMASTLOCK`=0도 두 포트에 출력한다.

- 명령 포트: 주소 단계는 IF 직전 클록, IF가 데이터 단계다. IF/ID와 예비 칸 1개가 있고, 데이터를 받을 칸이 보장될 때만 주소 단계를 낸다.
- 데이터 포트: LD/ST는 ID/EX에서 주소 단계를 내고 MEM/WB가 데이터 단계다. 주소 단계가 수락되는 에지에 명령이 MEM/WB로 발행된다.
- `HREADY`=0이면 NONSEQ 주소 단계와 쓰기 데이터를 유지한다. 대기 없는 slave에서 순차 명령 1개/클록, LD/ST 1개/클록이다.
- `HRESP`=ERROR는 2클록이다. 데이터 포트는 첫 클록을 기록해 둘째 클록에 다음 주소 단계를 IDLE로 취소하고, 오류 완료에서 fault 3으로 정지한다. 명령 포트의 오류는 그 명령이 실제로 실행될 때 fault 2가 된다.
- 분기·HALT·fault 뒤의 인출은 응답을 받아서 버린다. 잘못된 경로의 명령은 ID/EX에 들어가지 않으므로 데이터 포트 접근을 만들지 않는다.
- 오류로 끝난 전송의 RAM/UART 쓰기·FIFO pop/push 억제는 slave의 책임이다.
- reset 중 두 포트는 IDLE이다. 이미 반영한 외부 쓰기는 되돌리지 않는다.
- 포트 지연에 따라 처리율은 달라진다. 모든 명령이 고정 3클록이라는 규약은 아니다.

## 인터럽트 — 2026-11-03

| 항목 | 규칙 |
|---|---|
| 신호 | 입력 `i_irq`(level, `i_clk` 동기). 출력 `o_irq_active`(처리 루틴 실행 중), `o_retire_bank`(완료 명령의 레지스터 묶음, 시험용) |
| 허용 | IE는 reset 0. `EI`/`DI`로 바꾼다 |
| 진입 조건 | IE=1, 처리 루틴 밖, `i_irq`=1, ID/EX에 명령이 있고 MEM/WB가 비었거나 이번 클록에 완료 |
| 진입 동작 | ID/EX 명령은 실행하지 않고 그 PC를 EPC에 저장. 인출을 벡터 PC 0x0002로 돌림(분기처럼 뒤 인출 폐기). MEM/WB의 앞 명령은 완료한다(정확한 인터럽트). IE=0, 레지스터 묶음 1로 전환 |
| 레지스터 묶음 | 묶음 0 = 프로그램, 묶음 1 = 처리 루틴. 각각 R0~R3·X·FLAGS를 따로 가진다. 처리 루틴은 저장·복원 코드 없이 레지스터를 쓰고, 두 쪽은 RAM으로 데이터를 주고받는다. 묶음 1의 값은 다음 진입까지 유지된다 |
| 복귀 | `RETI`: PC=EPC, 묶음 0, IE=1. 버려졌던 명령부터 다시 실행 |
| 데이터 포트 | 인터럽트 대기 중에는 새 데이터 주소 단계를 내지 않는다. 이미 `HREADY`=0으로 붙잡힌 주소 단계가 있으면 그 LD/ST가 발행된 뒤 진입한다. 따라서 버려지는 LD/ST는 버스 접근(RAM 쓰기·UART pop 등)을 만들지 않는다 |
| 중첩·HALT | 중첩 없음(처리 중 요청은 `RETI` 뒤에 받음). HALT 뒤에는 깨어나지 않는다 |
| 지연 | 시험 조건(메모리 대기 포함)에서 요청부터 진입까지 최대 6클록 |

인터럽트를 쓰지 않는 프로그램의 동작과 클록 수는 추가 전과 같다(기존 64개 회귀 프로그램에서 완료 명령 수·클록·stall 동일).

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

**기본 실행은 Vivado에서 RTL/헤더와 TB를 추가하고 `tb_cpu8_top`을 simulation top으로 지정한 뒤 Behavioral Simulation을 실행하면 된다.**
별도 옵션 없이 TB에 내장한 네 명령으로10+20을 계산하고 결과·완료 순서를 검사해 `CPU8_DEMO_PASS`를 출력한다.
클록·리셋·시험 메모리는 TB가 만든다. 기본 시험에는 사용자 입력이나 외부파일이 필요 없다.

`CASES` 인자를 명시한 경우에만 기존 외부 시험 목록 모드를 사용한다. 아래 Python runner는 전체 88개 프로그램 회귀(인터럽트 24개 포함)·ALU/reset과 기본 무인자 데모를 함께 검증한다.
`PROGRAMS/first_add.asm`은 같은 프로그램의 별도 어셈블러 예제다. 기본 TB의 내장 ROM은 해당파일을 읽지 않는다.


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

## 이전 구현과 변경 이력

초기 설계에서는 이전 CPU의 ALU carry/overflow, 2R1W, 제어 신호와 enable/hold 개념을 참고했다.
사용자 요청에 따라 이전 RTL과 TB·실행 스크립트·파형 설정을 현재 트리에서 삭제했다.
이전 구현은 [삭제 전 커밋 abc28c6](https://github.com/OKSY1105/Basic_SoC_implementation/tree/abc28c60b85e8caaeb1be6e1d226521a4f0957ff/1_RTL/2_TINY_PROJECT/CPU/8bit_CPU)에서 확인할 수 있다.

첫 ROM 프로그램의 `080A / 0914 / 2401 / 0400`은 고정 입력 설명/단위 시험이다.
전체 계산기에서는 ROM 프로그램이 UART 데이터를 읽어 변환하여 계산해야 한다.
