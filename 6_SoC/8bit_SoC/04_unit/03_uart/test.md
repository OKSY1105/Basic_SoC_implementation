# UART 단위 검증

기존 [tb_uart.v](../../../../1_RTL/2_TINY_PROJECT/UART/tb_uart.v)의 top은 tb_uart_top이며 55/A5/00/FF 전송 확인과 tb_done/tb_error를 사용한다. 기존 TB는 $stop으로 멈추므로 자동 기능 PASS를 얻으려면 종료/실패 판정을 별도로 보강해야 한다.

실행: `python3 scripts/run_unit.py uart --vivado-bin /home/sean/Vivado/2024.2/bin`

이번 공용 runner 범위는 UART 코어+기존 TB와 Zybo 래퍼의 compile/elaboration이다. UART 기능 회귀 PASS나 보드 시험을 의미하지 않는다.

후속: TX 파형 독립 샘플링, RX 직렬 자극, FIFO full/empty/overflow, 연속 전송, frame 오류, reset, MMIO 중복 pop/push 방지를 자동 판정한다.

기존 RTL 일부에는 timescale이 없어 기존 TB와 함께 elaboration할 때 XSIM 43-4099가 발생했다. 새 runner/Tcl은 UART에 한해 `--timescale 1ns/1ps --override_timeunit --override_timeprecision`을 적용한다. 원본 RTL/TB 바이트는 변경하지 않았다.

## 2026-10-30 — 새 SoC 경로에서 확인

기록 시각: 2026-10-30T10:29:12+09:00. 시험 기록 시각: 2026-10-30T10:28:23+09:00. 기준 HEAD: 26113681a818e79aaac595fe1d28bc75b67c89a0 + 이번 미커밋 경로 개편. Vivado 2024.2 xvlog/xelab/XSim, 새 공용 runner all 실행.

- `tb_uart_top`: compile/elaboration PASS.
- `zybo_uart_top`: compile/elaboration PASS.

로그와 시험 소스 SHA-256은 외부 soc_reorg_20261030/test_logs 및 tested_source_fingerprints.json에 보관했다. FPGA 합성/타이밍/실물 시험은 이번에 실행하지 않았다.

## 2026-10-30 — 1_RTL 공용 원본 직접 참조 검증

기록 시각: 2026-10-30T16:43:44+09:00. 실제 실행 시각: 2026-10-30T16:40:03+09:00. 기준 HEAD 75659a8b0da4cd76446f2b7cf2c8e0ade82bf454 + 공용 라이브러리 복원/참조 수정. SoC run_unit.py와 sources.json이 1_RTL 원본을 직접 읽었다.

- `tb_uart_top`: compile/elaboration PASS.
- `zybo_uart_top`: compile/elaboration PASS.

도구: Vivado 2024.2 xvlog/xelab/XSim. UART는 compile/elaboration 범위다. 외부 soc_library_restore_20261030/test_logs와 verification.json에 로그·원본 SHA-256을 보관한다. 실제 보드·전체 SoC 시험은 미실행이다.

## 2026-11-03 — 코어에 `i_lsr_clr` 추가 후 기존 TB

`uart_rx`·`uart_top`에 오류 flag 지우기 입력 `i_lsr_clr[2:0]`을 추가했다. `tb_uart.v`·`zybo_uart_top.v`에는 `3'b000`을 연결했다([uart.md](../../02_design/uart.md) 코어 변경 절). 위 절의 "원본 RTL/TB 바이트는 변경하지 않았다"는 이 시점부터 해당하지 않는다.

기존 TB는 PASS 문자열이 없다. 그래서 `--debug typical`로 elaboration하고 실행 뒤 `tb_error`·`tb_done` 값을 읽어 판정했다(Windows Vivado 2024.2 XSim, `xelab --timescale 1ns/1ps`).

| 시점 | 결과 |
|---|---|
| 변경 전 | `tb_error=0 tb_done=1`, `$stop` 795,235 ns |
| 변경 후 | `tb_error=0 tb_done=1`, `$stop` 795,235 ns (같음). `zybo_uart_top` elaboration PASS |

## M9 UART APB 래퍼

- 대상: [soc8_uart_apb.v](../../rtl/uart/soc8_uart_apb.v), TB: [tb_soc8_uart_apb.sv](../../tb/uart/tb_soc8_uart_apb.sv)
- 구성
  - AHB master 모델 → [AHB→APB3 브리지](../../../../1_RTL/2_TINY_PROJECT/BUS/ahb_apb_bridge.v) → 래퍼 → UART 코어
  - UART 핀에 직렬 송수신 모델을 붙인다(8E1). 시험용 baud는 3.125 Mbaud(100 MHz에서 32클록/bit)다.
  - SVA: APB 규칙과 브리지의 AHB 응답 규칙
- 판정
  - APB ACCESS마다 `PREADY`=1과 `PSLVERR` 조건을 확인한다.
  - STATUS 읽기가 UART 상태 bit와 같아야 하고, IRQ_EN 읽기가 마지막으로 쓴 값과 같아야 한다.
  - 코어 신호(pop·push·flag 지우기)는 성공한 전송의 ACCESS 클록에만 나와야 한다.
  - AHB 결과가 APB 결과와 같아야 한다.
  - TXD 바이트 = 성공한 TX_DATA 쓰기(순서·parity·stop), RX_DATA 읽기 = RXD로 보낸 바이트(순서, overrun으로 버려진 바이트 제외)
  - IRQ는 매 클록 (상태 & IRQ_EN)을 레지스터에 담은 값과 같아야 한다.
  - ERROR_CLEAR는 쓴 bit만 지운다.
- 시나리오
  1. reset 값
  2. 오류 접근 9종(부작용 없음)
  3. TX 5바이트, TX FIFO가 찰 때까지 쓰기(17바이트 수락 뒤 ERROR)
  4. RX 3바이트
  5. overrun(17번째 바이트 버림)
  6. parity·frame 오류와 W1C bit별 지우기
  7. IRQ_EN 읽기
  8. IRQ 원인별 발생·해제(RX, TX 빔, parity·frame·overrun 각각 단독)
  9. TX 송신 중·RX 데이터 대기 중 reset
  10. RXD로 120바이트(parity·frame 오류 포함)를 받는 동안 무작위 레지스터 접근
- 통과 조건: `FAIL` 줄이 없고, 커버리지 항목이 모두 1 이상이며, `UART_APB_PASS`를 출력한다.

실행 (Windows, 빈 작업 폴더에서. WSL은 `xvlog`·`xelab`·`xsim`):

```sh
R=<저장소 루트>; B=$R/1_RTL/2_TINY_PROJECT/BUS; U=$R/1_RTL/2_TINY_PROJECT/UART
xvlog.bat $U/baud_rate_gen.v $U/fifo.v $U/uart_rx.v $U/uart_tx.v $U/uart_top.v
xvlog.bat --sv -d AHB_LITE_SVA -d APB_SVA $B/ahb_lite_master_bfm.sv $B/ahb_lite_slave_checker.sv $B/apb_checker.sv $B/ahb_apb_bridge.v $R/6_SoC/8bit_SoC/rtl/uart/soc8_uart_apb.v $R/6_SoC/8bit_SoC/tb/uart/tb_soc8_uart_apb.sv
xelab.bat --timescale 1ns/1ps tb_soc8_uart_apb -s tb_u
xsim.bat tb_u -runall
```

결과 (2026-11-04, WSL Vivado 2024.2 XSim, `apb_checker` 6번 검사 추가 후):

```text
COVER rx ok=161 empty=2898 write=408 | tx ok=230 full=1642 read=344 | status=2460 st_write=261 | clear=606 clear_read=252 | irq_en w=637 r=988 | unmapped=1492 hsize=1
COVER irq rx/tx/parity/frame/overrun=1/1/1/1/1 flags oe/pe/fe=1/1/1 resets=1 tx_frames=228 rx_bytes=161
UART_APB_PASS apb_transfers=12379 tx_bytes=228 rx_bytes=161 irq_sources=3 resets=1
```

- 2026-11-03 결과는 `apb_transfers=12305 tx_bytes=227`이었다. 검사가 하나 늘면 `$urandom` 시드 배정이 바뀌어 무작위 접근 수가 달라진다. 이전 검사기로 다시 실행하면 2026-11-03 값이 그대로 나온다(2026-11-04 확인). 검사기 변경 내용은 [BUS 단위 검증](../04_bus/test.md) M8 절.

변이 시험(저장소에 반영하지 않은 임시 사본, 최종 TB 기준 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| 빈 RX 읽기를 OKAY로 | `FAIL core strobes re/we/clr=10000 expected 00000` |
| 가득 찬 TX 쓰기를 OKAY로 | `FAIL core strobes re/we/clr=01000 expected 00000` |
| STATUS의 FE·PE bit 뒤바꿈 | `FAIL STATUS read 58, expected 68` |
| ERROR_CLEAR bit 위치를 [4:2]로 | `FAIL core strobes re/we/clr=00001 expected 00000` |
| TX IRQ 원인을 TX_EMPTY 대신 송신 완료(TEMT)로 | `FAIL IRQ=0, expected 1` |
| STATUS 쓰기를 OKAY로 | `FAIL PADDR=f02 W=1 PSLVERR=0, expected 1` |
| 미할당 `PADDR`를 OKAY로 | `FAIL PADDR=f05 W=0 PSLVERR=0, expected 1` |
| 오류 IRQ에서 OVERRUN 제외 | `FAIL IRQ=0, expected 1` |
| 오류 IRQ에서 FRAME_ERR 제외 | `FAIL IRQ=0, expected 1` |
| IRQ_EN 쓰기 bit를 [3:1]로 | `FAIL IRQ=0, expected 1` |
| 코어: FE 지우기 무시 | `FAIL ERROR_CLEAR 010: flags PE/FE/OE 111, before 111` |

- 처음 판의 TB는 "오류 IRQ에서 OVERRUN 제외" 변이를 잡지 못했다(PASS). IRQ_EN 오류 bit를 켠 상태에서 OVERRUN만 단독으로 생기는 경우가 없었기 때문이다. FRAME_ERR 단독도 같은 빈틈이 있었다. 두 경우를 시나리오 8에 넣은 뒤 두 변이 모두 FAIL로 잡혔다.
- 등가 변이(결과로 구별되지 않음): RX pop·TX push 조건에서 `!w_err`를 빼는 변이. 빈 FIFO의 pop과 가득 찬 FIFO의 push는 FIFO 자체가 무시한다. 다만 TB의 코어 신호 검사는 이 차이도 FAIL로 잡는다.

합성 (WSL Linux Vivado 2024.2, `xc7z020clg400-1` out-of-context, UART 코어 포함, 기본 115200 baud): LUT 217, FF 343, latch 0, 100 MHz WNS +5.76 ns(합성 추정). 경고는 위 `fifo.v` 메모리 구현 방식과 `PREADY` 상수 1뿐이다.
