# 목표와 범위

목적은 RTL 설계 및 검증 포트폴리오로 설명 가능한 소형 SoC를 만드는 것이다.

```text
PC 숫자·연산 요청 → FPGA UART RX → BUS/MMIO → RAM·CPU
                                            ↓
STM32 LCD 표시 ← STM32 UART RX ← FPGA UART TX ← 계산 결과
```

| 항목 | 기존 결정/상태 |
|---|---|
| CPU | 단일 코어·4×8bit GPR·16bit 명령·3단계·stall |
| 입력 | 부호 있는 −128~127 두 수, ADD/SUB/MUL/DIV 요청 |
| 결과 | 부호 있는 16bit, 나눗셈은 정수 몫과 나머지 |
| MUL/DIV | 전용 명령 추가 대신 프로그램 반복 방향 |
| 프로그램 공급 | 미리 준비한 ROM 프로그램, PC는 숫자와 연산 요청 전송 |
| RAM | 2KiB, CPU 측 8bit 바이트 접근 |
| 표시 | STM32 수신 후 WAT-LCD_BUTTON 표시 목표 |
| FPGA | Digilent Zybo Z7-20(`xc7z020clg400-1`) 확정(2026-11-04). 설계 클록 100 MHz — 보드 PL 입력 125 MHz(K17)를 MMCM으로 변환. 핀은 FPGA 단계에서 정한다 |
| UART | 115200 bps, 8E1. PC 터미널·STM32도 같은 설정(2026-11-04) |
| 통신 규약 | 줄 단위 ASCII 요청·응답과 오류 응답 — [계산기 통신 규약](../02_design/calculator.md)(2026-11-04) |

계산기 ROM 프로그램·SoC top·STM32 펌웨어는 후속 구현이다. 요청·응답 형식, 음수 나눗셈의 몫·나머지 부호, 0으로 나누기와 잘못된 입력의 응답은 [계산기 통신 규약](../02_design/calculator.md)에 정했다. RAM은 데이터 캐시 + 직접 만든 DRAM 제어기 구조다([RAM](../02_design/ram.md)).
