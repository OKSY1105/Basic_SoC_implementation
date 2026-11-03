# BUS 단위 검증

주소 최초/최종·RAM 경계 밖·미할당·slave 선택 배타성·긴 wait·연속 요청·reset·오류·부작용 1회를 독립 scoreboard로 검사한다. [sources.json](../../sources.json) 등록은 BUS 모듈이 모두 갖춰진 뒤 한다.

## M6 AHB 디코더·응답 선택기·기본 slave

- 대상: [soc8_ahb_bus.v](../../rtl/bus/soc8_ahb_bus.v), TB: [tb_soc8_ahb_bus.sv](../../tb/bus/tb_soc8_ahb_bus.sv)
- 구성: [공용 BUS 시험 도구](../../../../1_RTL/2_TINY_PROJECT/BUS)의 master 모델 1개, slave 모델 3개(ROM형 대기 0, RAM형 대기 0~6, APB형 대기 1~4, 각각 `HADDR[3:0]`=F에서 ERROR, 데이터 단계를 갖지 않을 때 무작위 출력), master 쪽 응답 규칙 SVA
- 판정: 매 클록 `HSEL`과 주소 맵 비교, 완료한 전송마다 응답·읽기 데이터 비교, slave마다 받은 전송 목록(주소·방향·쓰기 데이터·응답)이 그 slave로 가야 할 완료 전송과 순서까지 같은지, 기본 slave 디버그 출력(마지막 오류 주소·횟수)
- 시나리오: 경계 주소 10개(0000·1FFF·2000·7FFF·8000·87FF·8800·EFFF·F000·FFFF) 읽기·쓰기, 무작위 8,000건(ERROR 뒤 계속) + 8,000건(ERROR 뒤 다음 전송 취소), 전송 중 reset 20회, 기본 slave ERROR 첫 클록의 reset
- 통과 조건: `FAIL` 줄 없음, 커버리지 항목(영역별 OKAY·ERROR, 영역 간 연속 전송 16쌍, 다른 slave 대기 중 주소 단계 유지, 취소, reset, 미할당 IDLE, 비선택 slave의 `HREADYOUT`=0) 모두 1 이상, `AHB_BUS_PASS` 출력

실행 (Windows, 작업 폴더에서. WSL은 `xvlog`·`xelab`·`xsim`, 경로는 저장소 기준으로 같다):

```sh
R=<저장소 루트>; B=$R/1_RTL/2_TINY_PROJECT/BUS
xvlog.bat --sv -d AHB_LITE_SVA $B/ahb_lite_master_bfm.sv $B/ahb_lite_slave_model.sv $B/ahb_lite_slave_checker.sv $R/6_SoC/8bit_SoC/rtl/bus/soc8_ahb_bus.v $R/6_SoC/8bit_SoC/tb/bus/tb_soc8_ahb_bus.sv
xelab.bat tb_soc8_ahb_bus -s tb_bus
xsim.bat tb_bus -runall
```

결과 (2026-11-03, Windows Vivado 2024.2 XSim):

```text
COVER ops rom=4563 ram=4569 apb=3952 unmapped=3222 | errors rom=242 ram=238 apb=212
COVER cancels=1416 resets=21 cross_hold=13949 idle_unmapped=8024 boundary=29 max_wait=7 junk_low=23948/17751/19800
AHB_BUS_PASS transfers=16306 unmapped=3222 cancels=1416 resets=21 max_wait=7
```

변이 시험(저장소에 반영하지 않은 임시 사본, 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| 선택 레지스터를 `HREADY`와 무관하게 갱신 | `FAIL SVA a_err_second` |
| 기본 slave ERROR를 1클록으로 | `FAIL SVA a_err_first` |
| RAM 디코드를 0x8000~0x8FFF로(별칭) | `FAIL HSEL ... HADDR=8800` |
| APB 응답에 RAM의 `HREADYOUT` 사용 | `FAIL slave3: data phase ended while HREADYOUT=0` |
| 미할당 IDLE도 오류 횟수에 셈 | `FAIL default slave debug ...` |

## M8 AHB→APB3 브리지

- 대상: [ahb_apb_bridge.v](../../../../1_RTL/2_TINY_PROJECT/BUS/ahb_apb_bridge.v), TB: [tb_ahb_apb_bridge.sv](../../../../1_RTL/2_TINY_PROJECT/BUS/tb_ahb_apb_bridge.sv). 규칙과 실행 명령은 [BUS README](../../../../1_RTL/2_TINY_PROJECT/BUS/README.md) 브리지 절.
- 구성
  - AHB master 모델 → TB 내 디코더 → 브리지(0xF000~0xFFFF)와 다른 AHB slave(대기 0~4)
  - APB slave 모델: 대기 0~5, `PADDR[3:0]`=F에서 `PSLVERR`, ACCESS 밖에서 무작위 출력
  - SVA: APB 규칙과 브리지의 AHB 응답 규칙
- 판정
  - AHB 완료마다 응답·읽기 데이터·대기 클록 수(OKAY 2+w, `PSLVERR` 3+w, `HSIZE` 오류 1)
  - APB 전송 목록과 크기가 맞는 브리지 전송이 순서까지 1:1(`PADDR`=`HADDR[11:0]`·`PWRITE`·`PWDATA`=`HWDATA`). `HSIZE` 오류·IDLE·다른 slave 전송에는 APB 전송이 없어야 한다.
  - 다른 slave가 받은 전송 목록
- 시나리오: 지정 전송(OKAY·`PSLVERR` 읽기/쓰기, `HSIZE` 오류, 연속 브리지 전송, 브리지·다른 slave 교대), 무작위 6,000건 ×2(ERROR 뒤 계속/취소), APB SETUP·ACCESS 중 reset 20회
- 통과 조건
  - `FAIL` 줄 없음
  - 커버리지 항목 모두 1 이상: 각 응답 종류, APB 대기 0과 최대, 연속 브리지 전송, 다른 slave 대기 중 브리지 주소 단계 유지, 취소, SETUP·ACCESS 중 reset, ACCESS 밖 `PREADY`=1. 최소 지연은 2클록이어야 한다.
  - `APB_BRIDGE_PASS` 출력

결과 (2026-11-03, Windows Vivado 2024.2 XSim):

```text
COVER bridge read_ok=3210 write_ok=3084 read_slverr=180 write_slverr=200 hsize_err=639 | apb wait0=1131 wait5=1115
COVER b2b=2695 cross_hold=4127 idle_bridge=718 cancels=424 resets setup/access=14/6 junk_pready=18997 latency=2..7 other=4821
APB_BRIDGE_PASS apb_transfers=6674 slverr=380 hsize_err=639 latency=2..7 resets=20
```

변이 시험(저장소에 반영하지 않은 임시 사본, 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| SETUP 생략(바로 ACCESS) | `FAIL SVA a_access_stable` |
| ACCESS에서 `PREADY` 무시 | `FAIL SVA a_access_wait` |
| `PSLVERR` 무시 | `FAIL bridge HADDR=ff0f PSLVERR=1 AHB resp=0, expected 1` |
| `HSIZE` 검사 제거 | `FAIL bridge HADDR=ff02 HSIZE=1: resp=0 wait=5, expected ERROR after 1` |
| `HREADY`=0일 때도 주소 단계 수락 | `FAIL SVA a_access_stable` |
| ACCESS 중 `HREADYOUT`=1 | `FAIL SVA a_access_stable` |
| `PRDATA`를 담지 않음 | `FAIL bridge HADDR=ff00 read 00, expected ae` |
| AHB ERROR를 1클록으로 | `FAIL SVA a_err_second` |
| 완료 클록에도 `PSEL`=1 | `FAIL SVA a_setup_access` |

합성 (WSL Linux Vivado 2024.2, `xc7z020clg400-1` out-of-context, CLAUDE.md TS-B7): LUT 11, FF 27, latch 0, 100 MHz WNS +6.83 ns(합성 추정).

시험 작성 중 XSim 2024.2가 결과 확인 루프에서 `FATAL_ERROR: Vivado Simulator kernel has discovered an exceptional condition`으로 중단했다. 원인은 중첩 블록 안에서 다른 모듈의 구조체 큐 원소를 직접 읽은 부분으로 보인다. 값을 지역 변수로 먼저 복사하도록 고친 뒤 정상 동작했다.

## M10 리셋 동기화기

- 대상: [reset_sync.v](../../../../1_RTL/2_TINY_PROJECT/BUS/reset_sync.v), TB: [tb_reset_sync.sv](../../../../1_RTL/2_TINY_PROJECT/BUS/tb_reset_sync.sv). 규칙과 실행 명령은 [BUS README](../../../../1_RTL/2_TINY_PROJECT/BUS/README.md) 리셋 동기화기 절.
- 결과 (2026-11-03, Windows Vivado 2024.2 XSim):

```text
COVER pulses=206 glitches_without_edge=29 near_after=1 near_before=1 reassert=1 stopped_clock=1
RESET_SYNC_PASS pulses=206 glitches=29
```

- 첫 실행의 FAIL 1건은 TB의 시점 경합이었다. 무작위 펄스 시작이 "에지 +0.5 ns" 검사와 같은 시각(0.01 ns 단위)에 겹쳤다. 그래서 검사 시점을 +0.505 ns로 옮겼다. DUT 변경은 없다.

변이 시험(임시 사본, 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| assert를 동기식으로(`negedge i_rst_n` 제거) | `FAIL output not low right after assertion` |
| 출력을 첫 단에서 꺼냄 | `FAIL power-up: release on edges 1/1, expected 2/3` |
| 해제를 비동기로(출력 = 입력) | `FAIL STAGES=3 output rose between edges` |
| 모든 단을 한 번에 1로 | `FAIL power-up: release on edges 1/1, expected 2/3` |
| reset 값을 1로 | `FAIL STAGES=3 output rose between edges` |

합성 (WSL Linux Vivado 2024.2, `xc7z020clg400-1` out-of-context, `STAGES`=2): FDCE 2개(`ASYNC_REG`=1), LUT1 1개(reset 극성 반전), latch 0. `STAGES`=1은 elaboration 오류(`reset_sync_STAGES_must_be_at_least_2` 미정의 모듈)로 막힌다.
