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

## 2026-11-03 — M3: 줄 포트와 DQ/DQS 분리

변경: 제어기 로직을 `dram_controller_core`(DQ/DQS 분리)로 옮기고, `dram_controller`는 3상태 래퍼로 두었다. 줄 포트(`i_line`, `i_line_wdata`, `o_line_rdata`)를 추가했다. 규칙은 [DRAM 제어기 README](../../../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/README.md)에 있다. 기존 TB는 내부 신호 참조 3곳을 `dut.u_core.*`로 바꾸고 줄 포트 입력을 0으로 묶었다.

결과 (Windows Vivado 2024.2 XSim):

| TB | 결과 |
|---|---|
| `tb_dram_controller` (기존) | `DRAM_CONTROLLER_PASS: CL=9 CWL=10 tRCD=9 checks=30833 completions=4121 RD=4124 WR=2060 commits=2060`. 변경 전과 수치·종료 시각(6,187,690 ns) 동일 |
| `tb_dram_controller_alt` (기존) | `DRAM_CONTROLLER_PASS: CL=10 CWL=11 tRCD=12 checks=30833 ...`. 변경 전과 수치·종료 시각(7,177,130 ns) 동일 |
| `tb_dram_line` (신규) | `DRAM_LINE_PASS CL=9 CWL=10 tRCD=9 completions=2089 RD=1296 WR=1001 commits=1001`. 지연: 줄 읽기 94~95, 줄 쓰기 106~107, 바이트 읽기 94, 바이트 쓰기 202클록 |
| `tb_dram_line_alt` (신규) | `DRAM_LINE_PASS CL=10 CWL=11 tRCD=12 ...`. 지연: 110~111 / 122~123 / 110 / 234클록 |
| [`tb_cache_dram`](../../tb/ram/tb_cache_dram.sv) (신규, 캐시 + 제어기 + 모델) | `CACHE_DRAM_PASS accesses=3412 hit_rate=59% misses=1382 writebacks=574 miss_wait_avg=143 miss_wait_max=207`. 캐시 miss = RD 명령, 되쓰기 = WR = 모델 기록 |

실행 (빈 작업 폴더에서):

```sh
L=<저장소>/1_RTL/2_TINY_PROJECT; R=<저장소>
xvlog.bat $L/DRAM_CONTEOLLER/dram_controller.v $L/DRAM/dram.v
xvlog.bat --sv -d AHB_LITE_SVA $L/BUS/ahb_lite_master_bfm.sv $L/BUS/ahb_lite_slave_checker.sv $L/Cache/cache.v $R/6_SoC/8bit_SoC/tb/ram/tb_cache_dram.sv
xelab.bat tb_cache_dram -s tb_cache_dram
xsim.bat tb_cache_dram -runall
```

변이 시험(임시 사본, `tb_dram_line` 두 설정 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| 줄 쓰기를 RMW 경로로 | `FAIL line write: RD+1 WR+1 commit+1, expected 0/1/1` |
| 줄 쓰기 데이터를 담지 않음 | `FAIL line write 00 not in the model` |
| `o_line_rdata` 상·하위 뒤바꿈 | `FAIL line read 00 = ..., expected ...` |
| 코어 DQ 입력을 자기 출력에 연결 | `FAIL line read 00 = 5858...` (기존 바이트 TB도 FAIL) |
| 줄 읽기를 쓰기로 처리 | `FAIL line read 00 = 0000...`, 이후 전체 시간 한도 |
| 래퍼 DQ 구동을 DQS enable로 | `FAIL DQ driven (10) without the controller's DQ enable` |

- 마지막 변이는 처음 TB에서 **PASS(놓침)**였다. DQS enable이 쓰기 burst 끝에서 DQ enable보다 반 phase 길어 DQ를 더 구동하지만, 동작 모델은 그 시간에 DQ를 쓰지 않아 데이터 결과가 같았기 때문이다. "양쪽 enable이 0이면 DQ/DQS는 Z" 검사를 추가했다. 동작 모델은 reset이 없어 첫 ACT 전 enable이 X이므로, 확실한 0일 때만 판정한다. 그 뒤 검출했다.
- 처음 판의 줄 쓰기 표시 레지스터 `r_line`은 쓰이지 않는 로직이어서 제거했다. 줄 쓰기는 READ 상태를 지나지 않기 때문이다. 제거 뒤 다섯 TB를 다시 실행해 수치가 같음을 확인했다.

합성 (WSL Linux Vivado 2024.2, `dram_controller_core`, `xc7z020clg400-1` out-of-context): LUT 335, FF 155, F7 MUX 8, 3상태 셀 0, latch 0, 100 MHz WNS +3.70 ns(합성 추정).

## 2026-11-04 — M4: 보드용 BRAM DRAM 모델

변경: 보드용 모델 [`dram_bram_model.v`](../../../../1_RTL/2_TINY_PROJECT/DRAM/dram_bram_model.v)를 추가했다(규칙은 [DRAM README](../../../../1_RTL/2_TINY_PROJECT/DRAM/README.md)의 보드용 모델 절). 제어기 TB 두 개에 모델 선택(`-d DRAM_BRAM_MODEL`)을, `tb_dram_line.sv`에 두 모델 나란히 비교(`-d DRAM_MODEL_MATCH`)를 추가했다. 정의 없이 컴파일하면 이전과 같은 시험이다(모델 배열 접근만 매크로를 거친다).

결과 (WSL Vivado 2024.2 XSim, `scripts/run_dram_models_tb.sh`, `RESULT status=0`):

| TB | `dram.v` | `dram_bram_model.v` |
|---|---|---|
| `tb_dram_controller` | `DRAM_CONTROLLER_PASS: CL=9 CWL=10 tRCD=9 checks=30833 completions=4121 RD=4124 WR=2060 commits=2060`, 종료 6,187,690 ns(이전 기록과 같음) | 수치·종료 시각 모두 같음 |
| `tb_dram_controller_alt` | `DRAM_CONTROLLER_PASS: CL=10 CWL=11 tRCD=12 ...`(같은 수치), 종료 7,177,130 ns | 수치·종료 시각 모두 같음 |
| `tb_dram_line` | `DRAM_LINE_PASS ... completions=2089 RD=1296 WR=1001 commits=1001`(이전 기록과 같음) | `DRAM_LINE_PASS ... completions=2075 RD=1306 WR=1032 commits=1032`. 지연 줄 읽기 94~95, 줄 쓰기 106~107, 바이트 읽기 94, 바이트 쓰기 202클록(같음) |
| `tb_dram_line_alt` | `DRAM_LINE_PASS ... completions=2087 RD=1288 WR=1038 commits=1038` | `DRAM_LINE_PASS ... completions=2082 RD=1323 WR=984 commits=984`. 지연 110~111 / 122~123 / 110 / 234클록(같음) |

- 무작위가 없는 바이트 포트 TB는 두 모델에서 수치와 종료 시각이 ns까지 같다.
- 줄 포트 TB의 명령 수 차이: 모델 파일이 바뀌면 프로세스 수가 달라져 XSim의 프로세스별 `$urandom` 시드 배정이 바뀐다. 그래서 무작위 요청열 자체가 다르다. 정의 없는 기본 빌드는 이전 기록과 같은 수치이므로 TB 변경이 기존 시험을 바꾸지 않았다. 무작위 경로의 동작 일치는 아래 나란히 비교로 판정한다.
- 나란히 비교(`DRAM_MODEL_MATCH`, 행동 모델이 핀을 구동하고 보드용 모델이 같은 핀을 본다): `tb_dram_line` `MODEL_MATCH clocks=235481 read_dq_samples=20864 lines=256`, `tb_dram_line_alt` `MODEL_MATCH clocks=271769 read_dq_samples=21024 lines=256`, 둘 다 `DRAM_LINE_PASS`. 매 클록 읽기 DQ enable이 같고, enable 동안 데이터가 같으며, 끝에서 배열 256줄과 CL/CWL이 같다.

변이 시험(임시 사본, 보드용 모델로 실행, 모두 FAIL):

| 변이 | 첫 FAIL |
|---|---|
| CK high 첫 클록의 카운트 보정(`cnt + 1`) 제거 | `FAIL line read 00 = 39b1cbb42b6982zz, expected 3917cbb12bb48269` |
| 첫 beat의 짝수·홀수 바이트 뒤바꿈 | `FAIL line read 00 = 3917cbb12bb46982, expected 3917cbb12bb48269` |
| 쓰기 DQS_t·DQS_c 검출 뒤바꿈 | `FAIL line write 00 not in the model` |
| ACT의 행 주소 무시 | `FAIL line write 10 not in the model` |
| MR0의 CL 설정 무시(9 고정, `tb_dram_line_alt`) | `FAIL line read 00 = zzzz86ffa26f47be, expected 86ffa26f47be4367` |

합성 (WSL Vivado 2024.2, `scripts/synth_dram_bram.tcl`, 제어기 core + 보드용 모델 out-of-context, `xc7z020clg400-1`): `DRAM_BRAM_SYNTH_PASS` 전체 LUT 411, FF 240, BRAM 1(RAMB36E1), 모델만 LUT 81, FF 87, BRAM 1, latch 0, loop 0, 100 MHz WNS +3.367 ns(합성 추정, 최악 경로는 core 내부 `r_cycle` → `r_burst`).

- 처음 판은 배열을 `dram.v`와 같은 2차원 `mem[15:0][15:0]`으로 두었다. Vivado가 원소마다 "not inferred as ram due to incorrect usage"를 내고 레지스터로 풀었고, 스크립트의 BRAM 검사가 합성을 중단시켰다. 1차원 `mem[{row, col}]`으로 바꾸었고 TB는 매크로로 접근한다.

실행 (WSL, 저장소 루트 기준):

```sh
bash 6_SoC/8bit_SoC/scripts/run_dram_models_tb.sh /tmp/dram_models_tb
SOC8_SYNTH_BUILD=/tmp/dram_bram_synth vivado -mode batch -nojournal -source 6_SoC/8bit_SoC/scripts/synth_dram_bram.tcl
```
