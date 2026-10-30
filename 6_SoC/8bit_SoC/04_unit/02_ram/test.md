# RAM 단위 검증

제어기와 기존 행동 모델을 [tb_dram_controller.v](../../../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/tb_dram_controller.v)로 시험한다.

실행: `python3 scripts/run_unit.py ram --vivado-bin /home/sean/Vivado/2024.2/bin`

기본 top: tb_dram_controller(CL=9/CWL=10/tRCD=9). 대체 top: tb_dram_controller_alt(10/11/12). 한 바이트 쓰기·읽기, 2,048주소 독립 저장, 이웃 바이트 보존, reset 취소/쓰기 drain을 자동 검사한다.

2026-10-29 Git 업로드 전에는 두 설정 각각 30,833 checks PASS였다. 이 과거 증거와 이번 새 경로 실행은 구분한다. 실제 DDR PHY/PRE/REF/FPGA 타이밍/실물 검증은 포함하지 않는다.

## 2026-10-30 — 새 SoC 경로에서 확인

기록 시각: 2026-10-30T10:29:12+09:00. 시험 기록 시각: 2026-10-30T10:28:23+09:00. 기준 HEAD: 26113681a818e79aaac595fe1d28bc75b67c89a0 + 이번 미커밋 경로 개편. Vivado 2024.2 xvlog/xelab/XSim, 새 공용 runner all 실행.

- `tb_dram_controller`: simulation PASS.
  - `DRAM_CONTROLLER_DEMO_PASS: address 0 write 10/read 10`
  - `DRAM_CONTROLLER_ADDRESS_PASS: 2048 writes, 2048 reads, neighbor preservation`
  - `DRAM_CONTROLLER_RESET_PASS: idle retention, read cancel, write drain (short/held reset)`
  - `DRAM_CONTROLLER_PASS: CL=9 CWL=10 tRCD=9 checks=30833 completions=4121 RD=4124 WR=2060 commits=2060`
- `tb_dram_controller_alt`: simulation PASS.
  - `DRAM_CONTROLLER_DEMO_PASS: address 0 write 10/read 10`
  - `DRAM_CONTROLLER_ADDRESS_PASS: 2048 writes, 2048 reads, neighbor preservation`
  - `DRAM_CONTROLLER_RESET_PASS: idle retention, read cancel, write drain (short/held reset)`
  - `DRAM_CONTROLLER_PASS: CL=10 CWL=11 tRCD=12 checks=30833 completions=4121 RD=4124 WR=2060 commits=2060`

로그와 시험 소스 SHA-256은 외부 soc_reorg_20261030/test_logs 및 tested_source_fingerprints.json에 보관했다. FPGA 합성/타이밍/실물 시험은 이번에 실행하지 않았다.

## 2026-10-30 — 1_RTL 공용 원본 직접 참조 검증

기록 시각: 2026-10-30T16:43:44+09:00. 실제 실행 시각: 2026-10-30T16:40:03+09:00. 기준 HEAD 75659a8b0da4cd76446f2b7cf2c8e0ade82bf454 + 공용 라이브러리 복원/참조 수정. SoC run_unit.py와 sources.json이 1_RTL 원본을 직접 읽었다.

- `tb_dram_controller`: simulation PASS.
  - `DRAM_CONTROLLER_DEMO_PASS: address 0 write 10/read 10`
  - `DRAM_CONTROLLER_ADDRESS_PASS: 2048 writes, 2048 reads, neighbor preservation`
  - `DRAM_CONTROLLER_RESET_PASS: idle retention, read cancel, write drain (short/held reset)`
  - `DRAM_CONTROLLER_PASS: CL=9 CWL=10 tRCD=9 checks=30833 completions=4121 RD=4124 WR=2060 commits=2060`
- `tb_dram_controller_alt`: simulation PASS.
  - `DRAM_CONTROLLER_DEMO_PASS: address 0 write 10/read 10`
  - `DRAM_CONTROLLER_ADDRESS_PASS: 2048 writes, 2048 reads, neighbor preservation`
  - `DRAM_CONTROLLER_RESET_PASS: idle retention, read cancel, write drain (short/held reset)`
  - `DRAM_CONTROLLER_PASS: CL=10 CWL=11 tRCD=12 checks=30833 completions=4121 RD=4124 WR=2060 commits=2060`

도구: Vivado 2024.2 xvlog/xelab/XSim. UART는 compile/elaboration 범위다. 외부 soc_library_restore_20261030/test_logs와 verification.json에 로그·원본 SHA-256을 보관한다. 실제 보드·전체 SoC 시험은 미실행이다.
