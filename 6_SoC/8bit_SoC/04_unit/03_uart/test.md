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
