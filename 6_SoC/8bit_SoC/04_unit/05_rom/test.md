# ROM 단위 검증

## M5 프로그램 ROM

- 대상: [soc8_rom.v](../../rtl/rom/soc8_rom.v), TB: [tb_soc8_rom.sv](../../tb/rom/tb_soc8_rom.sv), 이미지: [rom_test.mem](../../tb/rom/rom_test.mem)
- 구성
  - 포트 A: [공용 BUS 시험 도구](../../../../1_RTL/2_TINY_PROJECT/BUS)의 master 모델(17bit 주소, 16bit 데이터). CPU 명령 포트처럼 점대점으로 연결한다.
  - 포트 B: master 모델 → [AHB 디코더](../../rtl/bus/soc8_ahb_bus.v) → ROM 포트 B. RAM·APB 영역에는 대기가 있는 slave 모델을 두어, 다른 slave가 `HREADY`를 낮춘 동안 ROM 주소 단계가 기다리게 한다.
  - 두 포트 모두 응답 규칙 SVA를 적용하고, `MAX_WAIT`=0으로 OKAY 대기를 금지한다.
- 판정: TB가 내용 사본을 따로 가진다(같은 이미지 파일에서 읽고, 뒤에는 계층 참조로 채움). 완료한 전송마다 다음을 비교한다.
  - 응답
  - 읽기 데이터·바이트 위치
  - 대기 클록 수: OKAY 0, ERROR 1
- 시나리오
  1. 이미지 확인: 포트 A로 모든 워드 4,096개, 포트 B로 모든 바이트 8,192개를 읽는다(이미지 밖은 0).
  2. 무작위 내용, 두 포트 동시 접근: 각 12,000건(포트 B는 ERROR 뒤 계속 / 취소 각 절반)
     - 잘못된 전송을 섞는다: 쓰기, 잘못된 `HSIZE`, 홀수 주소, 범위 밖 명령 주소
     - 접근이 몰리는 영역을 두고, 끝에 두 포트가 워드 4개만 연속으로 읽는 구간(각 2,000건)을 넣어 같은 클록에 같은 워드를 읽게 한다.
  3. 전송 중 reset 15회, 포트 A ERROR 첫 클록 reset. 그 뒤 모든 워드를 다시 읽어 reset 후에도 내용이 유지되는지 확인한다.
- 통과 조건
  - `FAIL` 줄이 없다.
  - 커버리지 항목이 모두 1 이상이다: 각 오류 종류, 짝수·홀수 바이트, 첫·끝 워드와 바이트, 다른 slave 대기 중 ROM 주소 단계 유지, reset. 같은 워드 동시 읽기는 100회 이상이다.
  - `ROM_PASS`를 출력한다.

실행 (Windows, 빈 작업 폴더에서. WSL은 `xvlog`·`xelab`·`xsim`):

```sh
R=<저장소 루트>; B=$R/1_RTL/2_TINY_PROJECT/BUS; T=$R/6_SoC/8bit_SoC/tb/rom
cp $T/rom_test.mem .
xvlog.bat --sv -d AHB_LITE_SVA $B/ahb_lite_master_bfm.sv $B/ahb_lite_slave_model.sv $B/ahb_lite_slave_checker.sv $R/6_SoC/8bit_SoC/rtl/bus/soc8_ahb_bus.v $R/6_SoC/8bit_SoC/rtl/rom/soc8_rom.v $T/tb_soc8_rom.sv
xelab.bat tb_soc8_rom -s tb_rom
xsim.bat tb_rom -runall
```

결과 (2026-11-03, Windows Vivado 2024.2 XSim):

```text
COVER portA ok=21570 write=136 size=264 odd=247 range=362 | portB lo=8521 hi=9751 write=321 size=231 other=3617
COVER same_word=530 rom_hold=5150 resets=16 first/last A=11 B=11 image_words=48
ROM_PASS portA_ok=21570 portB_ok=18272 same_word=530 rom_hold=5150 resets=16
```

(같은 워드 동시 읽기 구간을 넣기 전 첫 판은 `same_word=6`이었다.)

변이 시험(저장소에 반영하지 않은 임시 사본, 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| 포트 B 바이트 위치 뒤바꿈 | `FAIL port B HADDR=0000 read 5a, expected 3c` |
| 포트 A 범위 검사 제거 | `FAIL port A HADDR=1fb96 ... response 0, expected 1` |
| 포트 A 홀수 주소 검사 제거 | `FAIL port A HADDR=00dcf ... response 0, expected 1` |
| 포트 A `HSIZE` 검사 제거 | `FAIL port A HADDR=01dde ... HSIZE=2 response 0, expected 1` |
| 포트 B 쓰기를 OKAY로 | `FAIL port B HADDR=0b4b wait 0` |
| 포트 A ERROR를 1클록으로 | `FAIL SVA a_err_first` |
| 포트 A 워드 주소를 `HADDR[11:0]`로 | `FAIL port A HADDR=00002 read 6652, expected c40b` |

한계: 포트 B 주소 단계 수락에서 `HREADY` 항을 빼는 변이는 등가다. ROM 내용이 바뀌지 않고 오류 상태는 `HREADY`=1일 때만 갱신되므로, 결과로 구별되지 않는다(읽기 횟수만 늘어남).
