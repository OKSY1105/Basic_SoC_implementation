# SAP 컴퓨터와 비교 — 교과서 8bit 컴퓨터에서 무엇을 바꿨나

『Digital Computer Electronics』(Albert Paul Malvino·Jerald A. Brown)의 SAP(Simple-As-Possible) 컴퓨터 SAP-1·SAP-2·SAP-3과 이 8bit SoC를 비교한다. SAP 쪽 내용은 책 Part II(SAP 장)의 구조도·명령 표·타이밍 쪽을 판독한 범위에서 적었다. 8085 프로그래밍 장(13~23장)과 Part I은 목차만 확인했다. 이 SoC 쪽 수치는 저장소의 설계·시험 문서를 출처로 적는다.

## 한눈에 비교

| 항목 | SAP-1 | SAP-2 | SAP-3 | 이 SoC (CPU8) |
|---|---|---|---|---|
| 데이터 폭 | 8bit | 8bit | 8bit | 8bit |
| 주소 | 4bit, 메모리 16칸 | 16bit PC | 16bit PC | 명령: 16bit word PC. 데이터: 16bit byte 주소(RAM 2 KiB `0x8000~0x87FF`, ROM `0x0000~0x1FFF`, UART `0xF000~0xFFFF`) — [BUS](../02_design/bus.md) |
| 레지스터 | 누산기 A, B | 누산기 중심, 범용 레지스터 몇 개 | B·C·D·E·H·L, SP, F(flag) | R0~R3(모두 범용), X(16bit 주소), FLAGS(Z·N·C·V). 인터럽트용 묶음을 하나 더 가진다 |
| 명령 수·길이 | 5개(LDA·ADD·SUB·OUT·HLT), 1바이트(opcode 4bit + 주소 4bit) | 수십 개, 1~3바이트 | SAP-2 확장(ADI·ACI·SUI·SBI·CPI, JM·JP·JC·JNC 등), 1~3바이트 | 20개, 모두 16bit 1 word — [명령어 표](../02_design/isa_table.md) |
| 제어 | 6단계 링 카운터(T1~T6)와 하드와이어 제어 행렬. 명령마다 같은 T-state를 차례로 거치고 한 번에 한 명령 | SAP-1 방식을 확장 | 〃 | IF / ID·EX / MEM·WB 3단 파이프라인, 해독기 조합 논리. 기본 1클록/명령, 바로 앞 결과 사용·분기 때 +1 |
| 버스 | 8bit 공용 W bus 하나(3상태 출력이 차례로 버스를 씀) | W bus 확장 | 〃 | AMBA AHB-Lite: 명령 포트 → ROM 점대점, 데이터 포트 → 주소 디코더 → ROM·캐시·APB 브리지. 대기(`HREADY`)와 오류 응답(`HRESP`)이 있다 |
| 메모리 | 16바이트 RAM(스위치로 프로그램 입력) | monitor ROM 2K + RAM | 〃 | ROM(BRAM, 계산기 펌웨어) + RAM 경로: 직접 사상 write-back 캐시 → DRAM 제어기 → DRAM 모델(보드는 BRAM 기반 모델) — [RAM](../02_design/ram.md) |
| 입출력 | 출력 레지스터 → LED 표시 | 입출력 포트, READY/ACKNOWLEDGE handshaking(폴링) | 〃 | UART(APB3 slave, 115200 bps 8E1, 수신 FIFO), 수신 인터럽트 — [UART](../02_design/uart.md) |
| 서브루틴·스택 | 없음 | CALL/RET | SP, 스택 | 없음(루틴을 펼쳐 씀) |
| 인터럽트 | 없음 | 판독 범위에 없음(폴링) | 판독 범위에 없음 | IRQ 1개, 정확한 인터럽트, 처리 루틴 전용 레지스터 묶음(저장·복원 명령 불필요), EI·DI·RETI |
| 클록·구현 | TTL 칩, 수동·단계 클록 스위치 | TTL | TTL | FPGA(Zybo Z7-20) 100 MHz, LUT 1,012·FF 981·BRAM 3, WNS +0.558 ns — [보드 README](../fpga/boards/zybo/README.md) |

## SAP에서 가져온 생각

| SAP | 이 SoC에서 |
|---|---|
| 제어 워드(CON): 명령·T-state마다 어떤 레지스터를 버스에 내고 어디에 실을지 정한 bit 묶음 | 해독기 출력(`o_write_reg`, `o_read_flags`, `o_memory` 등)이 같은 역할을 한다. 명령별로 표로 만들어 어셈블러·ISA 모델과 대조하는 일은 아직 하지 않았다 |
| monitor ROM: 전원을 켜면 ROM 프로그램이 입출력을 맡는다 | 계산기 펌웨어가 ROM에서 UART 요청 줄을 받아 계산하고 응답 줄을 보낸다 — [펌웨어](../firmware/README.md), [계산기 규약](../02_design/calculator.md) |
| READY/ACKNOWLEDGE handshaking: 장치가 준비됐는지 CPU가 반복 확인 | UART 수신을 인터럽트로 받는다. CPU는 기다리는 동안 반복 확인하지 않는다 |
| 수동·단계 클록: 스위치로 클록을 멈추고 한 단계씩 진행 | 아직 없다. 보드에서 명령을 하나씩 실행하는 단계 실행 모드로 만들 수 있다 |
| 명령어 표(SAP-3 부록) | [명령어 표](../02_design/isa_table.md): opcode·형식·flag와 TB로 잰 클록 수 |

## SAP보다 발전시킨 것

1. **파이프라인**: SAP-1은 모든 명령이 같은 T-state 순서를 끝까지 거친다. 이 CPU는 세 명령을 겹쳐 실행해 기본 1클록마다 하나씩 끝낸다. forwarding이 없어서 바로 앞 결과를 쓰면 1클록을 기다린다(측정값은 명령어 표).
2. **표준 버스와 대기·오류**: SAP의 W bus는 모든 장치가 같은 속도로 응답한다고 가정한다. 이 SoC는 AHB-Lite·APB3를 써서 느린 장치(캐시 miss 때 약 94~207클록, UART 최소 2클록)는 대기를 걸고, 없는 주소는 오류로 응답한다. CPU는 대기 동안 주소를 유지하고, 오류는 fault로 멈춘다.
3. **메모리 계층**: SAP는 메모리가 한 종류다. 이 SoC는 느린 DRAM 앞에 캐시를 두어 hit이면 대기 없이 끝낸다.
4. **인터럽트**: SAP 장에는 인터럽트가 없다. 이 CPU는 진행 중인 명령 상태를 정확히 지키며 처리 루틴으로 들어가고, 레지스터 묶음을 바꿔 저장·복원 없이 처리한다.
5. **검증**: 블록마다 SVA 규칙 검사, 독립 기준 모델과의 비교, 결함을 넣어 시험이 잡는지 확인하는 변이 시험을 했고, 별도 검증자(Codex)가 지정 커밋을 다시 실행했다 — [검증](../verification/README.md).

## SAP에 있고 아직 없는 것 (CPU 확장 후보)

| SAP 기능 | 없어서 생기는 일 | 확장하면 |
|---|---|---|
| CALL/RET, 스택(SP·PUSH·POP) | 같은 루틴을 여러 곳에 펼쳐 써서 펌웨어가 길다 | 서브루틴으로 줄인다 |
| 레지스터 쌍으로 주소 만들기(SAP-3 HL → M) | X는 즉시값(LDXL·LDXH)과 INX로만 바뀐다. 계산한 값을 주소로 쓰기 어렵다 | ROM 문자열 표·버퍼를 반복문으로 처리한다 |
| 시프트·회전 | 곱셈·나눗셈을 반복 덧셈·뺄셈으로 한다 | shift-add 곱셈, 복원 나눗셈으로 반복 수가 8회로 준다 |
| 반대·부호 조건 분기(JNZ·JNC·JM·JP) | JZ·JC만 있어 반대 조건은 분기를 두 번 쓴다 | 분기가 짧아지고 부호 비교가 쉬워진다 |
| OR·XOR·NOT | AND만 있다 | bit 처리와 문자 변환이 쉬워진다 |

이 확장은 ISA를 바꾸므로 CPU 모듈 검증·SoC 통합 검증·보드 확인을 다시 해야 한다. 진행 여부는 정하지 않았다.
