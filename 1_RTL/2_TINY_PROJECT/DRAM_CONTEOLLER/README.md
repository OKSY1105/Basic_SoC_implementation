# DRAM 제어기

[../DRAM/dram.v](../DRAM/dram.v) 행동 모델을 대상으로 하는 바이트·줄 접근 제어기다. 실제 DDR PHY나 JEDEC 전체 기능의 제어기는 아니다. 규칙의 원문은 [dram_controller.v](dram_controller.v) 머리말이다.

| 모듈 | 용도 |
|---|---|
| `dram_controller_core` | 제어기 본체. DQ/DQS를 출력·출력 enable·입력으로 나눈 판(3상태 없음). FPGA 안의 메모리(BRAM 기반 합성 가능 모델 [../DRAM/dram_bram_model.v](../DRAM/dram_bram_model.v))에 연결한다 |
| `dram_controller` | 같은 제어기에 3상태 버퍼만 둔 래퍼. inout DQ/DQS로 행동 모델 `dram.v`에 연결한다 |

## host 포트

| 항목 | 규칙 |
|---|---|
| 핸드셰이크 | 요청 1개. `i_req`·`i_line`·`i_write`·`i_addr`·데이터를 `o_ready`까지 유지하고, `req && ready`인 상승 에지에서 한 번 완료한다. `o_ready`는 1클록이며 다음 요청은 이후 IDLE에서 받는다 |
| 주소 | 로컬 11bit `{row[3:0], column[3:0], offset[2:0]}` (2 KiB) |
| 바이트 (`i_line`=0) | 읽기 = RD 1회, 쓰기 = RMW(RD 1회 + WR 1회). offset 0 = [7:0] |
| 줄 (`i_line`=1) | 64bit 줄 = BL8 1회, 주소 [10:3](offset 무시), 바이트 k = [8k+7:8k]. 읽기 = RD 1회, `o_line_rdata`가 `o_ready`와 함께 유효. 쓰기 = WR 1회(RMW 없음). 데이터 캐시의 포트 |
| reset | 동기식 active-low. RD/WR 예약 전이면 즉시 취소, RD 예약 뒤면 burst를 마치고 취소, WR 예약 뒤면 burst와 모델 기록까지 마친다(완료 신호 없음) |

## 지연 (CL=9·CWL=10·tRCD=9, 시스템 클록)

| 접근 | 클록 |
|---|---|
| 줄 읽기 / 바이트 읽기 | 94 |
| 줄 쓰기 | 106 |
| 바이트 쓰기(RMW) | 202 |

CL=10·CWL=11·tRCD=12에서는 각각 110 / 122 / 234클록이다.

## 시험

| TB | 대상 | 기대 출력 |
|---|---|---|
| `tb_dram_controller.v` (`tb_dram_controller`, `tb_dram_controller_alt`) | 바이트 포트: 2,048주소 쓰기·읽기, 이웃 바이트 보존, reset 취소·drain | `DRAM_CONTROLLER_PASS` |
| `tb_dram_line.sv` (`tb_dram_line`, `tb_dram_line_alt`) | 줄 포트 | `DRAM_LINE_PASS` |

`tb_dram_line.sv`는 다음을 판정한다.
- 모든 줄 쓰기·읽기와, 바이트 접근을 섞은 무작위 1,500건
- 명령 수: 줄 쓰기는 WR 1·RD 0, 줄 읽기는 RD 1
- 모델 배열과 기준이 같은지
- 되쓰기 뒤 줄 채우기로 이어지는 캐시식 연속 요청
- reset: WR 전 취소, WR 뒤 drain, 읽기 중 reset
- DQ 충돌이 없는지, enable이 없을 때 DQ/DQS가 Z인지

```sh
L=<저장소>/1_RTL/2_TINY_PROJECT
xvlog.bat $L/DRAM_CONTEOLLER/dram_controller.v $L/DRAM/dram.v $L/DRAM_CONTEOLLER/tb_dram_controller.v
xvlog.bat --sv $L/DRAM_CONTEOLLER/tb_dram_line.sv
xelab.bat tb_dram_line -s tb_dram_line
xsim.bat tb_dram_line -runall
```

두 TB는 메모리 모델을 고를 수 있다(2026-11-04).

| 컴파일 | 메모리 모델 |
|---|---|
| `dram.v`, 정의 없음 | 행동 모델(기본) |
| `dram_bram_model.v`, `-d DRAM_BRAM_MODEL` | 보드용 BRAM 모델. 같은 검사를 이 모델에서 한다 |
| 두 파일, `-d DRAM_MODEL_MATCH` (`tb_dram_line.sv`만) | 행동 모델이 핀을 구동하고, 보드용 모델이 같은 핀을 보며 매 클록 읽기 DQ enable·데이터를 비교한다. 끝에서 배열 256줄과 CL/CWL을 비교한다 |

세 방식을 모두 실행하는 스크립트는 `6_SoC/8bit_SoC/scripts/run_dram_models_tb.sh`(WSL XSim)이다. 무작위 시험의 RD/WR 수는 모델마다 다르다. 모델 파일이 바뀌면 프로세스 수가 달라져 XSim의 프로세스별 `$urandom` 시드 배정이 바뀌기 때문이다. 그래서 무작위 경로의 일치는 `DRAM_MODEL_MATCH`의 같은 실행 안 비교로 판정한다.

결과와 변이 시험은 [SoC RAM 단위 검증](../../../6_SoC/8bit_SoC/04_unit/02_ram/test.md)에 있다.
