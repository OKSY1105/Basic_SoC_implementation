# 8-bit MIPS-style CPU Core RTL

## 범위
- 최상위 RTL 모듈: `cpu_top`
- CPU 내부의 최상위 계층은 `cu`(control unit), `du`(data unit) 두 개.
- 외부 **단일 8-bit 주소·데이터 인터페이스**를 사용해 명령어·데이터 접근을 공유하는 폰 노이만 구조.
- 8-bit 데이터 폭, 16-bit 고정 길이 명령어, 8-bit 바이트 주소 PC, 내부 8x8-bit IRF.
- CPU 안에 ROM, RAM, Flash, UART, AHB-Lite 없음. 테스트벤치 `TB/tb_cpu_top.v`의 `tb_bytes` 배열은 **테스트 전용**이며 CPU RTL에 포함되지 않음.
- 폴더명 대문자, RTL 파일명·모듈명 소문자.

## 파일 구조
```
CPU/
  cpu_top.v
  CU/
    cu.v
    instruction_decoder.v
    fsm.v
  DU/
    du.v
    ir.v
    pc.v
    irf.v
    alu.v
    ext.v
    mux.v
TB/
  tb_cpu_top.v
```

## 명령어 비트 형식 (16-bit)
원본 GabrielGiurgica 8-bit-MIPS-Processor의 명령어 구획을 따르되, **주소 단위와 분기 의미를 폰 노이만 바이트 인터페이스에 맞춰 수정**했습니다. 32-bit 정식 MIPS ISA와 바이너리 호환되지 않습니다.

```
R  [15:12]=0000  [11:9]=rs  [8:6]=rt  [5:3]=rd  [2:0]=funct
I  [15:12]=opcode[3:0] [11:9]=rs [8:6]=rt [5:0]=imm6
J  [15:12]=1010  [11:8]=0000 (reserved) [7:0]=absolute byte target
```

| Format | 명령어 | 코드 |
|---|---|---|
| R | AND, OR, NOR, ADD, SUB, SLT(signed), SLTU(unsigned) | opcode 0; funct 1..7 |
| I | ANDI, ORI, ADDI, ADDUI, SLTI, SLTUI | opcode 1..6 |
| I | LW, SW, BEQ | opcode 7,8,9 |
| J | J | opcode A |

- `R0`는 항상 `0`; 쓰기 무시. `R1`~`R7`는 범용 8-bit 레지스터.
- `ADDI`/`SLTI`는 `imm6` sign-extension. `ANDI`/`ORI`/`ADDUI`/`SLTUI`는 zero-extension.
- `LW`/`SW`는 **8-bit 1바이트** 접근. 유효 바이트 주소 = `rs + zeroextend(imm6)`, wraparound 8-bit. 이름은 참고 프로젝트와 동일하지만 정식 MIPS `LW/SW`의 32-bit 단어 접근을 의미하지 않음.
- `BEQ rs, rt, imm6`: 두 레지스터가 같으면 `PC_next = PC + 2 + (signext(imm6) << 1)`, 아니면 `PC + 2`. 목표 주소는 8-bit 바이트 주소.
- `J target`: 명령어의 하위 8-bit가 절대 **바이트 주소**. 상위 4-bit는 reserved (`0`). 명령어 주소는 짝수 값으로 정렬된다고 가정하며 정렬 예외 로직은 이번 범위에 포함하지 않음.
- CPU는 16-bit 명령어를 **big-endian byte order**로 가져옴: `[PC]`에 명령어 상위 8-bit, `[PC+1]`에 하위 8-bit.
- 미정의 Opcode/Funct는 데이터를 변경하지 않고 PC를 +2 증가시키는 안전한 NOP 동작으로 처리.

## 외부 공유 버스(메모리 프로토콜 구현 아님)
```
clk, rst_n
mem_req, mem_we, mem_addr[7:0], mem_wdata[7:0] -> 외부
mem_rdata[7:0], mem_ready                   <- 외부
```
- `mem_req=1, mem_we=0`이면 읽기, `mem_req=1, mem_we=1`이면 쓰기.
- `mem_req && mem_ready`가 **클럭 상승 엣지**에 참일 때 1바이트를 수락/전달함. 읽기 데이터는 해당 엣지에 유효해야 함.
- `mem_ready=0`인 동안 CPU는 주소와 읽기/쓰기 요청을 유지하며 기다림.
- Instruction fetch HI/LO 및 Data Read/Write는 하나의 포트에서 **순차 실행**함.
- 인터페이스는 표준 AHB-Lite, AXI, UART가 아님.

## 설계 계층
- `cu`: `instruction_decoder` + `fsm` (별도 추가 모듈 없음).
- `du`: `ir`, `pc`, `irf`, `alu`, `ext`, 재사용 `mux`.
- `pc.v`: 사용자 `counter.v`의 기본 증가 레지스터 개념에서 8-bit PC/enable/hold/branch-load로 수정.
- `irf.v`: 사용자 `filp_flop.v`의 8-bit DFF 개념을 8개 레지스터, 2R1W로 확장.
- `ir.v`: 사용자 Register 예제의 16-bit byte-enable 형태를 참고해 만든 상/하위 바이트 IR.
- `fsm.v`: 사용자 FSM의 상태/next-state 구성을 CPU 다중 사이클 상태로 수정.
- `alu.v`: 사용자 `alu_32b.v`, `ALU_4bit.v`를 8-bit RISC 명령어 연산에 맞게 축소 및 개선.
- `mux.v`: 사용자 MUX 기능을 파라미터 비트 폭의 4:1 MUX로 정리해 여러 곳에서 인스턴스화.
- `ext.v`: 즉시값 확장 논리는 새로 작성.
- 외부 참고: https://github.com/GabrielGiurgica/8-bit-MIPS-Processor

## Testbench
`TB/tb_cpu_top.v`에서 명령어와 데이터를 모두 공급. 동일 바이트 배열을 명령어/데이터로 공유하지만 배열은 CPU 하드웨어가 아닌 **검증 환경**에만 존재. 의도적인 2-cycle 외부 대기 상황에서 버스 신호 유지, 산술/논리 연산, immediate, LW/SW, BEQ taken/not taken, J를 검사.

예시 iverilog 명령:
```
iverilog -g2012 -s tb_cpu_top -o cpu_sim.vvp CPU/cpu_top.v CPU/CU/*.v CPU/DU/*.v TB/tb_cpu_top.v
vvp cpu_sim.vvp
```
