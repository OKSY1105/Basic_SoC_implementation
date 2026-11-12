# PC UART 도구

PC에서 보드의 계산기 펌웨어에 요청 줄을 보내고 응답 줄을 자동으로 판정하는 도구다. PC는 [계산기 통신 규약](../02_design/calculator.md)의 숫자 줄·연산 줄만 보낸다. CPU opcode를 입력하는 방식은 쓰지 않는다.

## 시험 화면 — `calc_ui.py` (2026-11-09)

계산기 보드를 시험하는 화면이다. Ubuntu에서 명령 하나를 실행하면 Windows 화면에 시험 창이 열린다. 사례·기준 모델·가짜 장치는 아래 `calc_board_test.py`의 것을 그대로 쓴다.

```sh
bash scripts/calc_ui.sh          # 8bit_SoC 폴더에서. 끝낼 때는 이 터미널에서 Ctrl+C
```

[`scripts/calc_ui.sh`](../scripts/calc_ui.sh)는 USB-UART 변환기(0403:6001)와 Nucleo ST-LINK(0483:374b)를 WSL에 붙이고, `calc_ui.py`를 실행한다. `calc_ui.py`는 두 장치를 USB ID로 찾아 열고(`--port`·`--stm32-port` 기본 `auto`), WSL interop으로 Chrome(없으면 Edge, 둘 다 없으면 기본 브라우저)의 앱 창에 `http://localhost:8765`를 띄운다. ST-LINK가 있으면 응답을 STM32 출력에서 읽고(`--reply-from stm32`, 지금 배선), 없으면 변환기 RX에서 읽는다. 이미 실행 중이면 창만 다시 연다. miniterm이나 `calc_board_test.py`가 실행 중이면 시작하지 않는다.

| 화면 영역 | 내용 |
|---|---|
| 1. 계산 보내기 | A·B를 넣고 ADD·SUB·MUL·DIV 버튼을 누르면 숫자 줄(`A,B`)과 연산 줄을 함께 보낸다(버튼 한 번에 결과 하나). 직접 입력 줄은 한 줄을 그대로 보낸다. 연산 줄에는 기대값을 함께 표시하고 받은 줄과 비교한다. 화면을 처음 열었을 때는 보드에 남아 있는 A·B를 모르므로(이전 사용 값이 남는다), 숫자를 보내거나 BTN0 버튼을 누르기 전의 연산 줄은 판정하지 않는다 |
| 2. 결과 | FPGA가 PC 변환기로 보낸 마지막 응답과, STM32가 받아 LCD에 표시한 마지막 줄(`--stm32-port`를 줄 때) |
| 3. BTN0 | 보드 BTN0을 누른 뒤 `BTN0 눌렀음`을 누르면 화면의 기대값 계산도 A·B가 없는 상태로 돌아간다. 자동 시험의 BTN0 단계도 이 버튼으로 진행한다 |
| 4. 자동 시험 | `calc_board_test.py`와 같은 고정 사례·BTN0 단계·parity 오류 사례·무작위 줄. 줄마다 기대값, PC 응답, LCD 줄, 판정을 표로 보여 주고 끝에 `CALC_UI_PASS`나 `CALC_UI_FAIL`을 표시한다 |
| 기록 | 보낸 줄, 받은 줄, STM32 출력, 안내를 시간 순서로 표시한다 |

STM32 쪽 비교는 STM32 디버그 출력(ST-LINK 가상 COM, 115200 8N1)의 `#n FPGA> 응답` 줄을 읽어서 한다([STM32 README](../stm32/README.md)). `--stm32-port`를 주면 자동 시험에서 PC 응답과 LCD 줄이 모두 기대값과 같아야 통과다. STM32가 `LCD_WRITE_FAIL`(LCD 쓰기와 재시도 모두 실패)을 출력하면 그것도 실패로 센다.

판정 규칙(2026-11-12, Codex 검증 VR-014의 결함 I1~I5·I8 수정):

| 항목 | 규칙 |
|---|---|
| 계산 한 건 | 숫자 줄과 연산 줄, 기대값 계산을 한 묶음으로 보낸다. 다른 요청(다른 계산·직접 입력·BTN0·자동 시험 시작)은 앞 묶음이 끝날 때까지 기다린다(I1) |
| A·B 범위 | 계산 버튼 경로는 A·B가 -128~127 정수일 때만 보낸다. 범위 밖이면 오류를 돌려주고 아무것도 보내지 않는다. 범위 밖 숫자로 `ERR RANGE`를 시험할 때는 직접 입력을 쓴다(I2) |
| 줄 끝 | PC 변환기로 받은 응답은 CR LF로 끝나야 한다. LF만으로 끝난 줄은 기대값과 글자가 같아도 실패다(I3). STM32 출력으로 판정할 때(`--reply-from stm32`)는 STM32가 줄 끝을 검사해 `RX ERR`로 보낸다 |
| 시간 초과 | 자동 시험은 응답(또는 LCD 줄)이 `--timeout` 안에 오지 않으면 그 줄을 실패로 하고 멈춘다(`aborted=reply_timeout`). 늦게 온 응답을 다음 줄의 응답으로 짝짓지 않기 위해서다. 줄을 보내기 전에 이미 와 있는 줄이 있으면 그것도 실패다. 직접 보내기에서는 시간 안에 오지 않은 기대값을 버리고 "응답 없음"을 기록하며, 그 뒤에 온 응답은 "짝이 없는 응답"으로 표시한다(I4) |
| LCD 표시 | STM32가 `#n LCD_FAIL ...`(그 줄을 LCD에 표시하지 못함)을 출력하면 그 줄의 LCD 판정은 실패다. 시작할 때 `LCD_NOT_FOUND`가 나오면 STM32가 다시 시작할 때까지 LCD 판정은 모두 실패다(I5) |
| 입력 검사 | 자동 시험의 무작위 줄 수와 seed는 정수여야 한다. 상태를 바꾸기 전에 검사하고, 처리 중 예외가 나도 연결을 끊지 않고 오류를 돌려준다(I8) |

자체 시험 `calc_ui_selftest.py`(하드웨어 없음, 약 40초, `--quick`은 HTTP 표를 빼고 약 5초):

```sh
python3 pc_tools/calc_ui_selftest.py
```

| 시험 | 확인하는 것 | 2026-11-12 결과 |
|---|---|---|
| `concurrent_calc` | 계산 A의 숫자 줄 쓰기를 붙잡아 둔 사이 계산 B를 요청: B가 기다리고 선로 순서가 `1,2` → `ADD` → `10,20` → `MUL`, 두 응답이 각자 기대값과 짝지어짐 | ok |
| `late_reply_auto` | 첫 응답을 0.5초 늦게(시간 초과 0.2초): 자동 시험이 그 줄에서 멈추고(`aborted=reply_timeout`), 늦은 응답은 짝이 없는 응답으로 기록 | ok |
| `late_reply_manual` | 직접 보내기에서 늦은 응답: "응답 없음" 1건, 늦은 응답은 짝 없음, 다음 계산은 자기 기대값과 짝지어짐 | ok |
| `lf_only_manual` | LF만으로 끝난 응답은 직접 보내기에서도 불일치 + 줄 끝 표시 | ok |
| `lcd_fail_lines` | `LCD_FAIL` 줄, `LCD_NOT_FOUND` 뒤의 줄은 LCD 표시 실패, STM32 재시작 줄에서 해제 | ok |
| `http_*` 4건 | 잘못된 seed·줄 수, 범위 밖 A·B(200·-129·128·1.5), 읽을 수 없는 요청(`Content-Length: abc`)에 오류 응답과 idle 상태 유지, 그 뒤 정상 계산 | ok |
| `matrix` 14건 | 두 응답 모드 × 정상 장치와 결함 6종의 자동 시험(BTN0 단계·parity 사례·무작위 300줄 seed 1) | 정상 PASS(329줄·239응답). FAIL 실패 수: `rem_sign_of_b` 14, `silent` 1(첫 응답에서 멈춤), `parity_ignored` 1, `range_overwrites` 28, `lf_only` 239, `lcd_missing` 239. 두 모드 같음 |

응답을 읽는 곳(`--reply-from`)은 배선에 따라 고른다. Pmod 구멍 하나에는 선을 하나만 꽂을 수 있으므로, 브레드보드 없이 결합하면 FPGA TX(JC 1번)는 STM32 D0에만 가고 변환기 RX는 비게 된다.

| 배선 | 옵션 | 판정 |
|---|---|---|
| FPGA TX → 변환기 RX와 STM32 D0 모두(브레드보드로 나눔) | `--reply-from pc`(기본) | PC 응답과 LCD 줄 모두 기대값 |
| FPGA TX → STM32 D0만, 변환기는 TX → JC 2번만 | `--reply-from stm32` | STM32가 받은 줄(= LCD 줄)이 기대값. 화면에서 PC 응답 칸을 숨긴다 |

직접 실행할 때(`calc_ui.sh`를 쓰지 않을 때):

```sh
bash scripts/wsl_usb.sh attach 0403:6001                      # USB-UART 변환기(FT232R)
bash scripts/wsl_usb.sh attach 0483:374b                      # STM32 ST-LINK (LCD 비교를 할 때)
python3 pc_tools/calc_ui.py --list-ports                       # 장치 경로 확인
python3 pc_tools/calc_ui.py --port /dev/ttyUSB0 --stm32-port /dev/ttyACM0 --reply-from stm32   # 변환기 RX 미연결
python3 pc_tools/calc_ui.py --port /dev/ttyUSB0 --stm32-port /dev/ttyACM0
python3 pc_tools/calc_ui.py --port /dev/ttyUSB0                # STM32 없이 FPGA만
python3 pc_tools/calc_ui.py --fake                             # 하드웨어 없이 화면 확인
```

- 서버가 `CALC_UI_READY`를 출력하고 시험 창을 연다. `--no-open`이면 창을 열지 않으므로 브라우저에서 `http://localhost:8765`를 직접 연다. 끝낼 때는 Ubuntu 터미널에서 Ctrl+C를 누른다(창에는 "서버 연결 끊김"이 표시되며, 창은 직접 닫는다).
- `--port`·`--stm32-port`를 생략하면 USB ID로 찾는다. `--stm32-port none`: STM32를 쓰지 않는다.
- 시리얼 포트 하나는 프로그램 하나만 연다. miniterm이나 `calc_board_test.py`가 같은 포트를 쓰고 있으면 `CALC_UI_FAIL cannot open port`로 끝난다.
- `--http-port N`: 화면 포트 변경(기본 8765). `--timeout SEC`: 응답 대기 시간(기본 1.0초). `--fake-fault <결함>`: `--fake`의 가짜 계산기에 아래 자체 시험 표의 결함을 넣는다. `lcd_missing`은 계산기가 아니라 가짜 STM32에 LCD가 없는 경우다.

자체 시험(2026-11-09, 하드웨어 없음): `--fake`로 서버를 띄우고 화면이 쓰는 API로 자동 시험(BTN0 단계·parity 사례·무작위 300줄 seed 1)을 실행했다. 정상 장치는 `CALC_UI_PASS lines=329 replies=239 failures=0 lcd=on`이었고, 결함 장치 `rem_sign_of_b`·`silent`·`parity_ignored`·`range_overwrites`는 모두 FAIL(실패 14·239·1·28줄)이었다. Windows 브라우저에서 화면을 열어 `10,20` → `ADD` → `ADD:30` 표시도 확인했다. `--reply-from stm32`를 더한 같은 시험도 정상 PASS, 결함 4종 FAIL(실패 줄 수 같음)이었다.

보드 결합 시험(2026-11-09, `--reply-from stm32`, 배선: 변환기 TX → JC 2번, JC 1번 → Nucleo D0, GND 공통, LCD는 점퍼선 4가닥): 화면 API로 `10,40` → `ADD`를 보내 STM32가 받은 줄 `ADD:50`(기대와 같음)을 확인했고, 자동 시험(BTN0 단계 제외, parity 사례 포함, 무작위 100줄 seed 3)은 `CALC_UI_PASS lines=125 replies=87 failures=0 lcd=on reply_from=stm32`, `LCD_WRITE_FAIL` 0건이었다. BTN0 단계를 넣은 자동 시험은 사용자가 보드 버튼을 눌러야 하므로 아직 하지 않았다.

`calc_ui.sh` 확인(2026-11-09, 같은 배선): 장치를 `/dev/ttyUSB0`·`/dev/ttyACM0`로 찾아 `reply_from=stm32`로 시작하고 Chrome 앱 창을 열었다(`page opened on the Windows screen (chrome.exe)`). `7,-2` → `DIV` → STM32 `DIV Q:-3 R:1`(기대와 같음). 실행 중에 한 번 더 실행하면 창만 다시 열고 끝났다. 가짜 장치 자체 시험(`--no-open`)은 두 모드 모두 그대로 통과했다.

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
