# STM32 LCD 수신 펌웨어

FPGA 계산기가 보내는 응답 줄을 STM32가 받아 16×2 문자 LCD에 표시한다. 응답은 [계산기 통신 규약](../02_design/calculator.md)의 ASCII 한 줄(CRLF로 끝남, 최대 15자)이다. STM32는 받은 줄을 그대로 표시만 하며, 숫자 변환·재계산을 하지 않고 FPGA로 아무것도 보내지 않는다.

## 구성 — `calc_lcd/` (2026-11-09)

| 항목 | 내용 |
|---|---|
| 보드 | ST NUCLEO-F439ZI(STM32F439ZIT6) |
| 개발 방식 | bare-metal CMSIS 레지스터 접근, PlatformIO `framework = cmsis`. 사용자의 기존 `Embedded_System/Bare_Metal/platformIO/10_USART` 프로젝트와 같은 환경이다 |
| 클록 | 시작 코드가 둔 내부 HSI 16 MHz 그대로(PLL 없음). 시작할 때 `SystemCoreClock`을 디버그 출력에 찍는다 |
| LCD | YwRobot "LCM1602 IIC Shield V1": 16×2 문자 LCD(HD44780 호환) + PCF8574 계열 I2C 확장 칩. 4-bit, 쓰기 전용. 확장 칩 주소 0x27, bit 배치 P0 = RS, P1 = R/W, P2 = EN, P3 = 백라이트, P4~P7 = D4~D7(Arduino LiquidCrystal_I2C와 같은 배치, `src/lcd_i2c.c`) — 보드에서 표시 확인. 쉴드에는 SDA·SCL pull-up 저항이 없다 |
| 표시 | 1행 = 마지막 응답, 2행 = 비움(현재 결과만 표시, 2026-11-09 사용자 요청 — 이전 판은 2행에 그 전 응답을 표시했다). 수신 오류(parity·frame·noise·overrun)가 난 줄은 `RX ERR`, 16자를 넘는 줄은 `RX LONG`. 시작 화면은 `8bit SoC calc` / `waiting UART...` |
| 디버그 출력 | USART3 TX(PD8) → ST-LINK 가상 COM, 115200 8N1. 시작 정보(클록, I2C 주소 검색 결과, LCD 초기화 결과)와 받은 줄마다 `#번호 FPGA> 응답`을 출력한다 |

| 파일 | 역할 |
|---|---|
| `src/uart_fpga.c` | USART6 수신(PG9, AF8), 115200 **8E1**(`CR1.M = 1`, `PCE = 1`, `PS = 0`), 수신 인터럽트 + 256칸 링 버퍼, 오류 flag 수 집계 |
| `src/i2c1.c` | I2C1 master 100 kHz(PB8 SCL, PB9 SDA, AF4, open-drain, **내부 pull-up 켬** — 쉴드에 pull-up이 없다), NACK·시간 초과 처리, 멈춘 bus 복구(`i2c1_recover`: GPIO로 SCL 최대 9번 → STOP → I2C1 재설정) |
| `src/lcd_i2c.c` | 확장 칩 주소 찾기(0x27·0x3F 먼저, 그다음 0x20~0x27·0x38~0x3F), HD44780 4-bit 초기화, 16칸 한 줄 쓰기 |
| `src/uart_dbg.c` | USART3 디버그 출력과 `printf` 연결(`10_USART`에서 옮김) |
| `src/delay.c` | SysTick 바쁜 대기 |
| `src/main.c` | 줄 조립(CR 또는 LF로 끝, 빈 줄 무시), 오류 표시, LCD 2행 갱신. LCD 쓰기가 실패하면 bus 복구 → LCD 재초기화 → 한 번 더 쓰기, 결과를 `LCD_RECOVERED` 또는 `LCD_WRITE_FAIL`로 출력 |

## 연결

쉴드의 SDA·SCL은 Arduino R3의 SDA·SCL 자리(디지털 헤더 AREF 옆 두 핀)로 나온다. 쉴드를 Nucleo-144의 Zio 커넥터 바깥 줄에 그대로 꽂으면 이 두 핀이 D14(PB9)·D15(PB8)에 맞고 5V·GND도 맞는다(2026-11-09 보드에서 LCD 표시 확인). 쉴드 위의 `GND VCC SDA SCL` 4구멍은 핀이 납땜되어 있지 않아 쓰지 않는다. Nucleo-144의 A4·A5는 I2C1 핀이 아니다(A4 = PF5, A5 = PF10).

쉴드를 그대로 꽂으면 D0(FPGA 수신)이 가려진다. FPGA와 결합할 때는 쉴드를 꽂지 않고 쉴드 바닥 핀에서 암-수 점퍼선 4가닥(5V·GND·SDA·SCL)을 Nucleo에 연결한다.

| 신호 | Nucleo-144 커넥터(바깥 줄) | STM32 핀 | 상대편 |
|---|---|---|---|
| FPGA 응답 수신 | D0 | PG9 (USART6_RX) | Zybo Pmod JC 1번(V15, FPGA TX). 같은 선이 PC 변환기 RX에도 연결된다 |
| GND | GND | — | Zybo Pmod JC 5번 또는 11번 GND(공통 접지 필수) |
| LCD SDA | D14 | PB9 (I2C1_SDA) | 쉴드 R3 SDA 핀(바닥에서 로고가 바로 읽히는 방향으로 위쪽 줄 오른쪽 끝에서 2번째) |
| LCD SCL | D15 | PB8 (I2C1_SCL) | 쉴드 R3 SCL 핀(위쪽 줄 오른쪽 끝) |
| LCD 전원 | 5V | — | 쉴드 5V(아래쪽 8핀 묶음 왼쪽에서 4번째, 같은 방향) |
| LCD GND | GND | — | 쉴드 GND(아래쪽 8핀 묶음 왼쪽에서 2번째) |

- Nucleo-144의 Zio 커넥터는 두 줄이다. Arduino 핀은 핀 이름이 인쇄된 쪽(보드 가장자리, 금색 morpho 구멍 쪽) **바깥 줄**에만 있고, 칩 쪽 안쪽 줄은 다른 신호(CN8 안쪽 = SDMMC 등)다. 처음 점퍼선 연결에서 안쪽 줄에 꽂아 쉴드에 전원이 들어가지 않았다.
- Arduino 이름 → STM32 핀 대응은 PlatformIO에 설치된 STM32duino 변형 파일(`variant_NUCLEO_F4x9ZI.cpp`: D0 = PG9, D14 = PB9, D15 = PB8)과 사용자의 기존 `TEST_FPGA/uart_led`(PG9 = D0)로 확인했다. USART3 PD8·PD9가 ST-LINK 가상 COM에 연결된 것도 같은 변형 파일의 설정으로 확인했다. ST UM1974 원문 표는 열지 못했다.
- 쉴드에 pull-up이 없으므로 I2C 선의 High는 STM32 내부 pull-up(약 40 kΩ, 3.3 V)이 만든다. 5 V로 동작하는 쉴드의 I2C 확장 칩 입력 High 기준은 데이터시트상 0.7 × VDD(3.5 V)라 3.3 V는 기준 밖이지만, 이 쉴드에서는 주소 응답·LCD 표시가 정상이었다. 동작이 불안정하면 SDA·SCL에서 5 V로 4.7 kΩ pull-up을 단다(PB8·PB9의 5 V 허용 여부를 먼저 데이터시트로 확인).

## 빌드·올리기 (Ubuntu)

모든 단계를 Ubuntu(WSL2)에서 한다(2026-11-09 사용자 결정). 작업 PC에는 PlatformIO Core 6.2.0과 `ststm32` 플랫폼(GCC ARM 7.2.1, CMSIS STM32F4, OpenOCD)이 이미 있다.

```sh
cd 6_SoC/8bit_SoC/stm32/calc_lcd
~/.platformio/penv/bin/pio run                 # 빌드
bash ../../scripts/wsl_usb.sh list             # Nucleo ST-LINK의 BUSID 확인(처음 한 번은 host 관리자 `usbipd bind`)
bash ../../scripts/wsl_usb.sh attach <BUSID>   # ST-LINK를 WSL에 붙임
~/.platformio/penv/bin/pio run -t upload       # ST-LINK로 올림
python3 -m serial.tools.miniterm /dev/ttyACM0 115200   # 디버그 출력 보기(ST-LINK 가상 COM, 장치 이름은 다를 수 있음)
```

빌드 결과(2026-11-09, 현재 결과만 표시하는 판): 경고 0(`-Wall -Wextra`), RAM 696 B, Flash 7,300 B.

## 시험 순서

1. LCD 단독: 올린 뒤 디버그 출력에 `LCD addr=0x.. init=OK`가 나오고 LCD에 시작 화면이 보이는지 확인한다. 글자가 안 보이면 쉴드의 파란 가변 저항(명암)을 돌린다.
2. 수신 단독: PC USB-UART 변환기 TX를 D0에, GND를 GND에 연결하고 8E1로 `ADD:30` 줄을 보낸다. LCD 1행과 디버그 출력에 같은 줄이 나오는지 확인한다.
3. 결합: FPGA TX(Pmod JC 1번)를 PC 변환기 RX와 Nucleo D0에 함께 연결하고 GND를 공통으로 한다. PC에서 `calc_board_test.py`나 터미널로 사례를 보내, PC에 나온 응답과 LCD 1행이 같은지 확인한다(완료 범위 3단계, `calculator.md` 6절).

## 보드 시험 결과

**1. LCD 단독 — PASS (2026-11-09)**: 쉴드를 Nucleo에 그대로 꽂고 ST-LINK로 올렸다. 디버그 출력과 LCD 표시는 아래와 같다(사용자 확인 "글자 보여").

```text
8bit SoC STM32 LCD receiver
SystemCoreClock=16000000 Hz (expected 16000000)
I2C1 idle level: SCL(PB8)=1 SDA(PB9)=1
I2C1 scan (PB8 SCL, PB9 SDA): 0x27
LCD addr=0x27 init=OK (err=0)
USART6 RX PG9 (D0) 115200 8E1 ready
```

- 내부 pull-up 없이 시작한 첫 판은 SDA·SCL이 떠 있어 주소 응답이 없었다(`I2C1 scan: none`). 쉴드에 pull-up이 없다는 것을 내부 pull-up·pull-down으로 선 상태를 읽어 확인했고, 내부 pull-up을 켠 판에서 0x27이 응답했다.
- 중간에 판매 페이지 예제(다른 제품 WAT-LCD_BUTTON, 4-bit 병렬 RS = D8·EN = D9·D4~D7)를 따라 병렬 구동도 시험했으나, 이 쉴드의 D4~D9는 LCD에 연결되어 있지 않았다(LCD는 초기화되지 않은 상태의 1행 네모로 남음).

**3. FPGA 결합 — 자동 시험 PASS, BTN0 단계 미실행 (2026-11-09)**: 쉴드를 빼고 점퍼선 4가닥(바깥 줄)으로 LCD를 연결하고, Zybo Pmod JC 1번(FPGA TX) → D0, PC 변환기 TX → JC 2번, GND 공통으로 배선했다(변환기 RX는 비움). PC 시험 화면 [`calc_ui.py --reply-from stm32`](../pc_tools/README.md)로 STM32 디버그 출력의 받은 줄을 판정했다: `10,40` → `ADD` → `ADD:50`, 자동 시험(parity 사례 포함, 무작위 100줄) `CALC_UI_PASS lines=125 replies=87 failures=0`, `LCD_WRITE_FAIL` 0건.

- 결합 전 첫 시도에서 STM32가 `ERR NOARG`를 받았지만 LCD 쓰기가 `err=-1`(bus busy)로 실패했다. 전원이 켜진 상태에서 점퍼선을 옮겨 I2C bus가 멈춘 것으로 추정한다. 그래서 LCD 쓰기 실패 때 bus를 복구하고 LCD를 다시 초기화해 한 번 더 쓰게 했다. 복구 경로는 시험 빌드(`PLATFORMIO_BUILD_FLAGS=-DI2C_RECOVER_SELFTEST`, 시작 화면을 복구 경로로 쓰게 함)로 보드에서 확인했다: `LCD_RECOVERED first_err=-3 sda_before=1`, 이어서 시작 화면 표시. 실제로 멈춘 bus에서의 복구는 아직 재현하지 못했다.
- 선을 바꾼 뒤 LCD가 비어 있으면 Nucleo RESET(검은 버튼)을 누른다. 전원을 켤 때 LCD 초기화를 하기 때문이다.
- 빌드(2026-11-09 복구 추가 판): 경고 0, RAM 696 B, Flash 7,316 B.

2번(수신 단독)은 결합 시험으로 대신했다.
