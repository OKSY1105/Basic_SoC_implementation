# BUS 공용 모듈 개발 위치

재사용 가능한 BUS 모듈은 이곳에서 개발하고, 6_SoC/8bit_SoC는 해당 원본과 SoC별 주소 디코더·어댑터를 연결한다. 규격·포트·검증 기준은 SoC의 02_design/bus.md에서 먼저 정한다.

## AHB-Lite 시험 도구 (단일 전송)

| 파일 | 역할 |
|---|---|
| `ahb_lite_master_bfm.sv` | master 모델. `push()`로 넣은 전송을 파이프라인으로 실행(현재 데이터 단계 중 다음 주소 단계)하고, `HREADY`=0 동안 주소 단계와 `HWDATA`를 유지한다. 완료마다 `results[]`에 1건을 기록한다. IDLE 주소 단계에는 무작위 `HADDR`을 내고, `cancel_on_error`=1이면 ERROR 둘째 클록에 대기 중인 주소 단계를 IDLE로 바꾼 뒤 그 전송을 다시 낸다 |
| `ahb_lite_slave_model.sv` | slave 모델. 전송마다 `MIN_WAIT`~`MAX_WAIT` 무작위 대기, `HADDR[3:0]`=F는 2클록 ERROR, 읽기 데이터는 `ID`에 따른 주소 함수다. 데이터 단계를 갖지 않을 때는 출력을 무작위로 낸다(`JUNK`). 완료한 전송을 `log[]`에 기록한다 |
| `ahb_lite_slave_checker.sv` | slave 응답 규칙 SVA(`AHB_LITE_SVA` 정의 시): IDLE은 대기 없는 OKAY, ERROR는 2클록, OKAY 대기 상한. 위반 시 `FAIL` 줄을 출력하고 `fails`를 증가시킨다. 버스 전체를 master 쪽에서 볼 때는 `hsel`=1, `hreadyout`=버스 `HREADY`로 연결한다 |

사용 예: [8bit SoC AHB 버스 TB](../../../6_SoC/8bit_SoC/tb/bus/tb_soc8_ahb_bus.sv), [8bit SoC ROM TB](../../../6_SoC/8bit_SoC/tb/rom/tb_soc8_rom.sv), 아래 브리지 TB.

## APB3 시험 도구

| 파일 | 역할 |
|---|---|
| `apb_slave_model.sv` | APB3 slave 모델. 전송마다 `MIN_WAIT`~`MAX_WAIT` ACCESS 대기, `PADDR[3:0]`=F는 `PSLVERR`, 읽기 데이터는 `ID`에 따른 주소 함수다. ACCESS 밖에서는 `PREADY`·`PSLVERR`·`PRDATA`를 무작위로 낸다(`JUNK`). 완료한 전송(주소·방향·데이터·`PSLVERR`·대기 수)을 `log[]`에 기록한다 |
| `apb_checker.sv` | APB3 master 쪽 규칙 SVA(`APB_SVA` 정의 시): `PENABLE`은 `PSEL`과 함께, SETUP 1클록 뒤 ACCESS, ACCESS 동안 `PADDR`·`PWRITE`·`PWDATA` 유지, `PREADY`까지 ACCESS 유지, 마지막 ACCESS 뒤 `PENABLE` 내림 |

## AHB→APB3 브리지 — `ahb_apb_bridge.v`

AHB-Lite slave 포트 1개를 APB3 master 포트 1개로 바꾼다. APB slave가 하나이면 `PSEL`을 그대로 연결하고, 여럿이면 APB 디코더가 `PADDR`로 `PSEL`을 나눈다. 파라미터는 `HADDR_W`(16)·`PADDR_W`(12)·`DATA_W`(8)이다.

| 항목 | 규칙 |
|---|---|
| AHB 수락 | `HSEL && HTRANS[1] && HREADY`. `PADDR` = `HADDR[PADDR_W-1:0]`, `PWRITE`를 이때 저장 |
| 전송 크기 | 바이트(`HSIZE`=000)만. 그 밖은 APB 전송 없이 2클록 ERROR |
| 시간표 | 주소 단계 다음 클록이 SETUP(`PSEL`=1), 그다음이 ACCESS(`PENABLE`=1, `PREADY`까지), 그다음 클록에 AHB 데이터 단계 완료. AHB 대기 = 2 + APB 대기(최소 2클록) |
| 응답 | `PRDATA`와 응답을 레지스터에 담아 낸다. `PSLVERR` → AHB 2클록 ERROR(대기 = 3 + APB 대기) |
| `PWDATA` | `HWDATA`를 그대로 연결. AHB master가 대기 중인 데이터 단계 동안 `HWDATA`를 유지하고, 브리지는 APB 전송이 끝날 때까지 `HREADYOUT`=0이므로 SETUP~ACCESS 동안 안정하다 |
| 전송 사이 | `PSEL`이 최소 1클록 내려간다(연속 전송도 SETUP부터 다시) |
| 클록 | `PCLK` = `HCLK` |
| 출력 | `HREADYOUT`·`HRESP`·`HRDATA`·`PSEL`·`PENABLE`은 레지스터 상태에서만 나온다. IDLE은 대기 없는 OKAY |

시험 `tb_ahb_apb_bridge.sv`: AHB master 모델 → TB 내 디코더 → 브리지(0xF000~0xFFFF) + 다른 AHB slave(대기 0~4) / APB slave 모델(대기 0~5). 다음을 판정한다.
- AHB 완료마다 응답·읽기 데이터·정확한 대기 클록 수
- APB 전송 목록이 크기가 맞는 브리지 전송과 순서까지 1:1인지(`PADDR`·`PWRITE`·`PWDATA`)
- 다른 slave의 전송 목록
- APB 규칙 SVA와 브리지 AHB 응답 SVA

시나리오는 지정 전송, 무작위 6,000건 ×2(ERROR 뒤 계속/취소), APB SETUP·ACCESS 중 reset 20회다.

```sh
B=<저장소>/1_RTL/2_TINY_PROJECT/BUS
xvlog.bat --sv -d AHB_LITE_SVA -d APB_SVA $B/ahb_lite_master_bfm.sv $B/ahb_lite_slave_model.sv $B/ahb_lite_slave_checker.sv $B/apb_slave_model.sv $B/apb_checker.sv $B/ahb_apb_bridge.v $B/tb_ahb_apb_bridge.sv
xelab.bat tb_ahb_apb_bridge -s tb_br
xsim.bat tb_br -runall
```

결과 (2026-11-03, Windows Vivado 2024.2 XSim): `APB_BRIDGE_PASS apb_transfers=6674 slverr=380 hsize_err=639 latency=2..7 resets=20`. 변이 시험 9개와 합성 결과는 [BUS 단위 검증](../../../6_SoC/8bit_SoC/04_unit/04_bus/test.md)에 있다.

## 리셋 동기화기 — `reset_sync.v`

비동기로 들어오는 active-low reset(보드 버튼, 또는 버튼 AND MMCM locked)을 클록 영역에 맞춘다.

| 항목 | 규칙 |
|---|---|
| assert | `i_rst_n`이 low가 되면 `o_rst_n`도 클록 없이 즉시 low(비동기) |
| 해제 | `i_rst_n`이 high가 된 뒤 `i_clk`의 `STAGES`번째 상승 에지에 `o_rst_n`이 high(동기). 기본 `STAGES`=2, 2 미만이면 elaboration 오류 |
| 사용 | 출력 하나를 비동기 reset 모듈(`posedge clk or negedge rst_n`)과 동기 reset 모듈(`posedge clk`, `if (!rst_n)`, 예: `cpu8_top`)이 함께 쓴다. 1클록보다 짧은 입력 펄스도 출력을 최소 `STAGES`-1개 상승 에지 동안 low로 유지하므로 동기 reset 모듈도 reset된다 |
| 합성 | FF 2개(FDCE)에 `ASYNC_REG` 속성. Vivado가 두 FF를 붙여 놓고 동기화기로 다룬다 |

시험 `tb_reset_sync.sv`: `STAGES`=2·3 인스턴스와, `STAGES`=2 출력을 쓰는 동기 reset 카운터·비동기 reset 카운터를 둔다. 다음을 판정한다.
- assert가 같은 시각에 일어나는지(전원 투입·클록 정지 중 포함)
- 입력 low 동안 모든 에지에서 출력이 low인지
- 해제가 상승 에지에서만, 정확히 `STAGES`번째 에지에 일어나는지
- 두 카운터가 모든 펄스에서 지워지고 같은 클록에 해제되는지

시나리오는 전원 투입, 에지 0.1 ns 뒤·앞 해제, 0.3 ns·2 ns 글리치, 해제 도중 재assert, 무작위 펄스 200회, 클록 정지다.

```sh
B=<저장소>/1_RTL/2_TINY_PROJECT/BUS
xvlog.bat --sv $B/reset_sync.v $B/tb_reset_sync.sv
xelab.bat tb_reset_sync -s tb_rst
xsim.bat tb_rst -runall
```

결과 (2026-11-03, Windows Vivado 2024.2 XSim): `RESET_SYNC_PASS pulses=206 glitches=29`(에지 없이 끝난 글리치 29회). 변이 시험 5개와 합성 결과는 [BUS 단위 검증](../../../6_SoC/8bit_SoC/04_unit/04_bus/test.md)에 있다.
