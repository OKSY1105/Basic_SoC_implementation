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
