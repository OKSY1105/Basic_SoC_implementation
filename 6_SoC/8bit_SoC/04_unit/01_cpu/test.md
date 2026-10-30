# CPU 단위 검증

현재 코어 구현과 기존 회귀 결과는 [기존 기록](../../../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/TEST_STATUS_PIPELINED.md)을 유지한다. 2026-10-28 기본 XSim 및 과거 Icarus 회귀는 과거 증거이며 이번 경로 개편 결과와 구분한다.

실행: `python3 scripts/run_unit.py cpu --vivado-bin /home/sean/Vivado/2024.2/bin`

기대: `CPU8_DEMO_PASS: 10 + 20 = 30`, R0=30/R1=20/regs=0000141E/pc=4/halted=1/fault=0. BUS·실제 RAM/UART와 연결한 시험은 아직 아니다.

## 2026-10-30 — 새 SoC 경로에서 확인

기록 시각: 2026-10-30T10:29:12+09:00. 시험 기록 시각: 2026-10-30T10:28:23+09:00. 기준 HEAD: 26113681a818e79aaac595fe1d28bc75b67c89a0 + 이번 미커밋 경로 개편. Vivado 2024.2 xvlog/xelab/XSim, 새 공용 runner all 실행.

- `tb_cpu8_top`: simulation PASS.
  - `CPU8_DEMO_PASS: 10 + 20 = 30; R0=30 R1=20 PC=4`

로그와 시험 소스 SHA-256은 외부 soc_reorg_20261030/test_logs 및 tested_source_fingerprints.json에 보관했다. FPGA 합성/타이밍/실물 시험은 이번에 실행하지 않았다.

## 2026-10-30 — 1_RTL 공용 원본 직접 참조 검증

기록 시각: 2026-10-30T16:43:44+09:00. 실제 실행 시각: 2026-10-30T16:40:03+09:00. 기준 HEAD 75659a8b0da4cd76446f2b7cf2c8e0ade82bf454 + 공용 라이브러리 복원/참조 수정. SoC run_unit.py와 sources.json이 1_RTL 원본을 직접 읽었다.

- `tb_cpu8_top`: simulation PASS.
  - `CPU8_DEMO_PASS: 10 + 20 = 30; R0=30 R1=20 PC=4`

도구: Vivado 2024.2 xvlog/xelab/XSim. UART는 compile/elaboration 범위다. 외부 soc_library_restore_20261030/test_logs와 verification.json에 로그·원본 SHA-256을 보관한다. 실제 보드·전체 SoC 시험은 미실행이다.
