# SoC 통합 TB — `tb_soc8_top.sv`

③ 통합 2·3단계(2026-11-04). [SoC top](../../rtl/soc/README.md)과 시뮬레이션용 DRAM 연결 회로([`sim/models/soc8_dram_model.v`](../../sim/models/soc8_dram_model.v))를 [통합 계획](../../05_integration/README.md) I01·I02 기준으로 시험하고, 계산기 펌웨어([`firmware/calc.asm`](../../firmware/README.md))를 I03 기준으로 시험한다.

## 시험 프로그램 (`programs/`, 어셈블리)

| 파일 | 내용 | TB 기대값 |
|---|---|---|
| `ram_basic.asm` | 0x8000~0x80FF에 v(i) = 3 + 7i 쓰기(32줄 = 캐시의 4배라 write-back 발생) → 다시 읽어 합계 → ROM 표(워드 0x0100) 4바이트 읽기 → UART로 송신 → HALT | UART 80 12 34 56 78, 접근 512·miss 64·write-back 32 |
| `uart_echo_irq.asm` | IRQ_EN = RX, EI, 대기 루프. 처리 루틴(벡터 0x0002, 레지스터 묶음 1)이 앞 진입에서 받은 바이트를 TX_DATA로 보내고 RX_DATA를 pop한 뒤 RETI. pop이 RETI 직전 마지막 접근이라 IRQ 여유 0클록 경우를 시험한다 | 보낸 b0..bn-1에 대해 송신 00, b0..bn-2, 처리 루틴 진입 정확히 n회 |
| `fault_unmapped.asm` | 'A' 송신 뒤 0x4000(미할당) LD | fault code 3, 그 LD에서 정지, 오류 주소 0x4000·횟수 1 |
| `fault_rom_write.asm` | ROM 영역(0x0010)에 ST | fault code 3, 그 ST에서 정지, ROM 불변, 기본 slave 횟수 0 |
| `../../firmware/calc.asm` | 계산기 펌웨어([규약](../../02_design/calculator.md)) | TB 기준 모델의 응답 |

## 시험과 판정

| 시험 | 내용 |
|---|---|
| `ram_basic` | 위 프로그램. DRAM 명령 수(RD = miss, WR = write-back = 모델 기록)와 최종 내용(캐시 줄 + 모델 = 기준)까지 본다 |
| `uart_echo_irq` | 40바이트(앞 절반은 간격 없이, 뒤 절반은 0~3 bit 간격). 송신 측 클록 정상 / 1.5% 빠름(24바이트) / 1.5% 느림(24바이트). UART 오류 flag가 없어야 한다 |
| `fault_unmapped`, `fault_rom_write` | 위 프로그램 |
| `reset_mid_run` | `ram_basic` 실행 중 무작위 reset 20회(캐시 miss 중·DRAM burst 중, 1클록보다 짧은 펄스 포함) 뒤 끝까지 실행해 결과 확인 |
| `calc` | 계산기 펌웨어. TB 안의 기준 모델(규약 2~4절을 그대로 옮긴 SV 함수)이 줄마다 기대 응답을 만든다. 지정 64줄(규약 5절, 경계값 `-128·-128`·`-128/-1`·`127-(-128)`, 오류 4종, 대소문자, 빈 줄, 줄 끝 CR·LF·CRLF 교대), 간격 없이 보낸 5줄 묶음, parity 오류가 난 줄, 무작위 120줄(빠른 baud만). 처리 루틴 진입 수 = 보낸 문자 수, 남는 송신 바이트 없음, UART 오류 flag 정리도 본다 |

- 데이터 포트 점수판: 버스에서 끝난 모든 전송을 본다. RAM 읽기는 그 바이트에 마지막으로 쓴 값(reset 뒤 아직 쓰지 않은 바이트는 처음 읽은 값을 기억), ROM 읽기는 이미지 바이트와 같아야 한다. ERROR 완료 수를 센다.
- UART: TXD에 8E1 수신 모델(parity·stop 검사), RXD에 8E1 송신 모델. reset에 걸린 프레임은 버린다.
- 캐시 ↔ DRAM 제어기: 모든 응답이 제어기가 받은 요청(주소·방향)의 것인지, reset 중이나 캐시가 기다리지 않을 때 응답이 없는지 본다. DQ 충돌 검사.
- SVA: AHB 버스·RAM slave 응답 규칙, APB3 master 규칙, CPU AHB master 규칙, CPU 인터럽트 규칙.
- 두 설정: 빠른 baud(3.125 Mbaud, 32클록/bit, 전체 8개 시험)와 115200 bps(`ram_basic` + 에코 8바이트 정상·1.5% 빠른 송신 + `calc` 무작위 제외).
- 통과 조건: 두 실행 모두 `SOC8_TOP_PASS`를 출력하고 `FAIL`로 시작하는 줄이 없다.

## 실행 (WSL Vivado 2024.2)

```sh
bash 6_SoC/8bit_SoC/scripts/run_soc8_top_tb.sh /tmp/soc8_top_tb    # 저장소 루트 기준. 종료 코드 0 = PASS
```

스크립트가 프로그램을 어셈블(`cpu8_asm.py`)하고, SVA를 켜서(`-d AHB_LITE_SVA -d APB_SVA -d CPU8_SVA`) 두 설정을 실행한다. 실행 폴더는 저장소 밖이다.

## 결과 (2026-11-04, 계산기 시험 추가 후)

```text
== fast
CASE ram_basic accesses=512 misses=64 writebacks=32 RD=64 WR=32 sum=80
CASE uart_echo_irq(sender x1.000) bytes=40 entries=40 uart_accesses=81
CASE uart_echo_irq(sender x1.015) bytes=24 entries=24 uart_accesses=49
CASE uart_echo_irq(sender x0.985) bytes=24 entries=24 uart_accesses=49
CASE fault_unmapped code=3 pc=0009 err_addr=4000
CASE fault_rom_write code=3 pc=0006
CASE reset_mid_run resets=20 in_read=4 in_write=11 other=5 short=2
CASE calc lines=191 chars=1125 replies=118 error_replies=40 entries=1125 random=1
COVER tests=8 uart_tx=99 irq_entries=1213 resets=20 rst_in_read=4 rst_in_write=11 rst_short=2
SOC8_TOP_PASS baud=3125000 tests=8 uart_tx=99 irq_entries=1213 resets=20
== real
CASE ram_basic accesses=512 misses=64 writebacks=32 RD=64 WR=32 sum=80
CASE uart_echo_irq(sender x1.000) bytes=8 entries=8 uart_accesses=17
CASE uart_echo_irq(sender x1.015) bytes=8 entries=8 uart_accesses=17
CASE calc lines=71 chars=387 replies=54 error_replies=22 entries=387 random=0
COVER tests=4 uart_tx=21 irq_entries=403 resets=0 rst_in_read=0 rst_in_write=0 rst_short=0
SOC8_TOP_PASS baud=115200 tests=4 uart_tx=21 irq_entries=403 resets=0
```

- `reset_mid_run`의 reset 시점 분포(READ drain 4·WRITE drain 11)는 계산기 시험을 넣기 전(2·4)과 다르다. TB 코드가 늘면 `$urandom` 시드 배정이 바뀌기 때문이다(CLAUDE.md TS-B10과 같은 현상).
- `uart_tx`·`COVER`의 송신 바이트 수에는 계산기 응답이 들어가지 않는다(응답은 `calc`의 `replies`로 센다).

### 이 TB가 찾은 결함

첫 실행에서 빠른 baud 에코 시험이 40바이트 중 하나를 잃었다. UART 수신 코어가 stop bit 끝에서야 대기 상태로 돌아가 간격 없는 다음 start bit를 놓친 것이다(송신 측 클록이 1% 빠르면 115200 bps에서도 생김). 모듈 검증(VR-009)은 프레임마다 idle bit를 넣는 RX 모델이라 이 경우를 시험하지 않았다. 수정과 단위 시험 보강은 [uart.md](../../02_design/uart.md) 코어 변경 절과 [03_uart/test.md](../../04_unit/03_uart/test.md) 2026-11-04 절에 있다.

### 변이 시험 (저장소에 반영하지 않은 임시 사본, `soc8_top.v` 연결 변경, 빠른 baud 실행)

| 변이 | 첫 FAIL |
|---|---|
| 캐시 → 제어기 줄 주소 1bit 밀림 | `FAIL DRAM ack for another request` |
| CPU `i_irq`를 0으로 묶음 | `FAIL uart_echo_irq(sender x1.000): 0 UART bytes, expected 40` |
| 버스의 RAM `HREADYOUT`을 1로 고정 | `FAIL RAM read 8000 = xx, expected 03` |
| ROM 포트 B `HSEL`을 RAM 선택으로 | `FAIL ROM read 0200 = 00, expected 12` |
| CPU `i_irq` 반전 | `FAIL SVA a_int_cond` |
| UART `PADDR[0]`을 0으로 고정 | `FAIL ram_basic: fault code 3 at 001b`(TX_DATA 쓰기가 RX_DATA로 가 PSLVERR) |

- 등가 변이(결과로 구별되지 않음): UART 래퍼의 `PSEL`·`PENABLE` 연결 뒤바꿈. 래퍼는 두 신호를 `PSEL && PENABLE`로만 쓰므로 동작이 같다.

### 펌웨어 변이 시험 (임시 사본, `calc.asm` 한 줄 변경, 빠른 baud의 FULL=0 실행)

| 변이 | 첫 FAIL |
|---|---|
| B의 범위 한계를 128 → 127(음수 한계 128) | `FAIL calc: line "MUL": reply "ERR RANGE", expected "MUL:16384"` |
| A의 범위 한계를 128 → 129 | `FAIL calc: line "-129,0": reply "", expected "ERR RANGE"` |
| DIV 부호에 A 대신 B의 부호 사용 | `FAIL calc: line "DIV": reply "DIV Q:3 R:1", expected "DIV Q:-3 R:-1"` |
| 대소문자 변환 마스크 제거(0xDF → 0xFF) | `FAIL calc: line "add": reply "ERR SYNTAX", expected "ADD:10"` |
| MUL 자리올림에 2를 더함 | `FAIL calc: line "MUL": reply "MUL:32768", expected "MUL:16384"` |
| 크기 0인 음수에도 '-' 출력 | `FAIL calc: line "DIV": reply "DIV Q:128 R:-0", expected "DIV Q:128 R:0"` |
| CR을 줄 끝으로 보지 않음 | `FAIL calc: line "ADD": reply "ERR SYNTAX", expected "ERR NOARG"` |

- 바꾸지 않은 사본은 PASS였다(대조군).
- 등가 변이: 줄 길이 한계 16 → 17. 올바른 줄은 길어야 9자이므로 16자 이상인 줄은 다른 규칙으로도 `ERR SYNTAX`다([규약](../../02_design/calculator.md) 8절).
