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
| FPGA | Zynq-7020 또는 Artix-7 후보, 최종 모델/핀/클록 재확인 |

BUS/ROM/UART 어댑터·패킷 문법·계산기 ROM 프로그램·STM32 펌웨어는 후속 구현이다. 음수 나눗셈의 반올림/나머지 부호, 0으로 나누기 응답, 잘못된 입력 및 시간초과를 문서화한 뒤 구현한다. Cache는 현재 통합 필수 범위로 추가하지 않는다.
