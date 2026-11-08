# PC UART 도구

PC에서 보드의 계산기 펌웨어에 요청 줄을 보내고 응답 줄을 자동으로 판정하는 도구다. PC는 [계산기 통신 규약](../02_design/calculator.md)의 숫자 줄·연산 줄만 보낸다. CPU opcode를 입력하는 방식은 쓰지 않는다.

## 보드 시험 — `calc_board_test.py` (2026-11-06)

[보드 TB](../tb/board/tb_soc8_zybo_top.sv)와 같은 사례를 실물 보드에 115200 bps 8E1로 보낸다. 응답은 이 파일 안의 기준 모델로 판정한다. 기준 모델은 규약 2~4절(숫자 범위, 0 방향 몫과 피제수 부호의 나머지, 오류 4종, 15자 제한)을 구현한 것이다. 고정 사례의 기대 문자열은 규약 5절과 보드 TB에서 옮겼고, 실행할 때마다 기준 모델이 이 문자열을 모두 그대로 만드는지 먼저 확인한다.

### 준비

- 모든 단계를 Ubuntu(WSL2)에서 한다(2026-11-09 사용자 결정). Python 3과 pyserial(`python3 -m pip install pyserial`). 작업 PC의 WSL Python 3.10.12에는 pyserial 3.5가 있다.
- 3.3 V USB-UART 변환기를 Pmod JC에 연결한다(Zybo Z7 참조 설명서 표 16.1, [보드 XDC](../fpga/constraints/soc8_zybo_z7_20.xdc)). 5 V 변환기는 쓰지 않는다.

  | 변환기 | Pmod JC 핀 | FPGA 핀 |
  |---|---|---|
  | TX | 2번 | W15 (`i_uart_rxd`) |
  | RX | 1번 | V15 (`o_uart_txd`) |
  | GND | 5번 | GND |

- 보드에 bitstream을 올린다([보드 README](../fpga/boards/zybo/README.md) "보드에 올리기"). 보드 J12의 USB-UART(FT2232H 채널 B)는 PS에 연결된 포트이므로 이 시험에 쓰지 않는다.
- 변환기를 WSL에 붙인다. WSL2는 USB를 직접 보지 못하므로 [`scripts/wsl_usb.sh`](../scripts/wsl_usb.sh)가 host의 usbipd-win을 Ubuntu에서 불러 붙인다. 변환기는 처음 꽂을 때 한 번 usbipd-win에 등록해야 한다(관리자 권한, `usbipd bind --busid <BUSID>`). 붙이면 `/dev/ttyUSB0`(CP210x·FTDI·CH340·PL2303) 또는 `/dev/ttyACM0`으로 보인다. 사용자 `sean`은 `dialout` 그룹이라 그대로 열 수 있다.

### 실행

8bit_SoC 폴더 기준이다(`/dev/ttyUSB0`은 예).

```sh
bash scripts/wsl_usb.sh list                                              # 변환기의 VID:PID·BUSID 확인
bash scripts/wsl_usb.sh attach <VID:PID 또는 BUSID>                       # 변환기를 WSL에 붙임
python3 pc_tools/calc_board_test.py --list-ports                          # 변환기의 장치 경로 확인
python3 pc_tools/calc_board_test.py --port /dev/ttyUSB0                   # 고정 사례(중간에 BTN0 reset 안내)
python3 pc_tools/calc_board_test.py --port /dev/ttyUSB0 --random 300 --seed 1 --log /home/sean/zybo_build/calc_board_result.txt
python3 pc_tools/calc_board_test.py --selftest                            # 하드웨어 없이 판정기 자체 시험
```

Zybo와 변환기가 모두 FTDI 칩이면 `/dev/ttyUSB*`가 여러 개 생긴다. `--list-ports`의 설명 열로 변환기를 고른다.

| 단계 | 내용 |
|---|---|
| 시작 | BTN0을 눌렀다 떼라는 안내 → A·B가 없는 상태에서 `ADD` → `ERR NOARG` |
| 고정 사례 | 규약 5절 사례 23줄: 4연산, 경계값(`-128,-128` MUL, `-128,-1` DIV), 부호 있는 나눗셈, 가장 긴 응답(`DIV Q:-10 R:-10`), `ERR DIV0`·`ERR RANGE`(A·B 유지)·`ERR SYNTAX`(공백, 쉼표 없음, 알 수 없는 연산, 16자) |
| 중간 reset | BTN0 안내 → `ADD` → `ERR NOARG`, `7,-2` → `DIV` → `DIV Q:-3 R:1` |
| parity 오류 | `ADD`를 odd parity로 보내고 CRLF는 even으로 보낸다 → `ERR SYNTAX`, 이어서 `SUB`는 정상(A·B 유지) |
| 무작위(선택) | `--random N`: 올바른 숫자 줄, 대소문자 섞은 연산 줄, 범위 밖 숫자, 형식 오류를 섞은 N줄 |
| 끝 | 기대하지 않은 남은 바이트가 없는지 확인 |

- 보내는 속도는 규약 2절을 따른다. 연산 줄을 보낸 뒤 응답(CRLF까지)을 받고 나서 다음 줄을 보내며, 숫자 줄은 응답이 없으므로 기다리지 않는다.
- 줄마다 `ok`나 `FAIL`을 출력하고, 끝에 `CALC_BOARD_PASS lines=… replies=… reply_ms min=… max=…`나 `CALC_BOARD_FAIL failures=…`를 출력한다. 종료 코드 0이 PASS다.
- `--no-prompt`: BTN0 단계와 그에 딸린 사례 4줄(`ERR NOARG` 2줄 포함)을 뺀다. `--no-parity-case`: parity 오류 사례를 뺀다. `--timeout SEC`: 응답 대기 시간(기본 1.0초).

### 자체 시험 (하드웨어 없음)

`--selftest`는 실제 포트 대신 계산기 규약을 따르는 가짜 장치로 실행한다. 이 가짜 장치는 기준 모델과 다른 방식으로 따로 작성했다(쉼표 분리, 실수 나눗셈 버림). 결함을 넣은 변형도 함께 실행해, 판정기가 그 결함을 실제로 잡는지 확인한다(BTN0 단계·parity 사례·무작위 400줄 포함).

| 가짜 장치 | 결함 | 기대 판정 |
|---|---|---|
| `correct` | 없음 | PASS |
| `rem_sign_of_b` | DIV 나머지를 제수 부호로 | FAIL |
| `silent` | 응답 없음 | FAIL |
| `lf_only` | 줄 끝을 LF만 보냄 | FAIL |
| `echo` | 받은 글자를 되돌려 보냄 | FAIL |
| `parity_ignored` | 수신 parity 오류 무시 | FAIL |
| `comma_space_ok` | 숫자 줄의 공백 허용 | FAIL |
| `range_overwrites` | `ERR RANGE` 때 A·B를 덮어씀 | FAIL |

결과(2026-11-06, Windows Python 3.9.13·WSL Python 3.10.12 같음):

```text
MODEL_TABLE_MATCH cases=29
SELFTEST device=correct verdict=PASS failures=0 expected=PASS ok
SELFTEST device=rem_sign_of_b verdict=FAIL failures=34 expected=FAIL ok
SELFTEST device=silent verdict=FAIL failures=303 expected=FAIL ok
SELFTEST device=lf_only verdict=FAIL failures=303 expected=FAIL ok
SELFTEST device=echo verdict=FAIL failures=303 expected=FAIL ok
SELFTEST device=parity_ignored verdict=FAIL failures=1 expected=FAIL ok
SELFTEST device=comma_space_ok verdict=FAIL failures=1 expected=FAIL ok
SELFTEST device=range_overwrites verdict=FAIL failures=32 expected=FAIL ok
SELFTEST_PASS
```

- 자체 시험은 판정기와 기준 모델의 자기 일관성만 확인한다. 실제 펌웨어의 응답과 기준 모델이 같다는 근거는 보드 TB·통합 TB(시뮬레이션)와 보드 실행 결과다.
- 보드 실행 결과는 아직 없다. 실행하면 이 절 아래에 기록한다.
