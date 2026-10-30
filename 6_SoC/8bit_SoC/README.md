# 8bit SoC — 공용 CPU·RAM·UART·BUS를 연결하는 프로젝트

PC의 UART 숫자·연산 요청을 8bit CPU가 계산하고 STM32 LCD에 결과를 표시하는 시스템을 만든다. 공용 모듈 원본은 `1_RTL/2_TINY_PROJECT`에 두고, 이 SoC가 그 파일들을 직접 읽는다.

## 진입 문서

- [현재 상태와 다음 작업](history.md#current)
- [개요](01_planning/overview.md) · [단계별 완료 기준](PROCESS.md)
- [공용 원본과 SoC의 경계](02_design/source_layout.md) · [설계 문서](02_design/README.md)
- [실행 방법](03_setup/README.md) · [원본 복원 기록](03_setup/migration.md)
- [단위 시험 결과](04_unit/README.md)

## 공용 모듈 원본

| 모듈 | 실제 저장 위치 |
|---|---|
| CPU | [1_RTL/2_TINY_PROJECT/CPU/8bit_CPU](../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU) |
| UART | [1_RTL/2_TINY_PROJECT/UART](../../1_RTL/2_TINY_PROJECT/UART) |
| DRAM 제어기/TB | [1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER](../../1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER) |
| DRAM 행동 모델 | [1_RTL/2_TINY_PROJECT/DRAM](../../1_RTL/2_TINY_PROJECT/DRAM) |
| BUS | [1_RTL/2_TINY_PROJECT/BUS](../../1_RTL/2_TINY_PROJECT/BUS) — 미구현 |

이 SoC에는 위 모듈의 사본이나 경로 심볼릭 링크를 두지 않는다. [sources.json](sources.json)과 [Vivado 생성 Tcl](scripts/create_vivado.tcl)이 원본 RTL/TB를 직접 참조한다.

## SoC 폴더 구성

```text
8bit_SoC/
├── 01_planning/        목적과 범위
├── 02_design/          인터페이스·주소·소유 경계
├── 03_setup/           환경·실행·경로 기록
├── 04_unit/            공용 모듈 시험 결과
├── 05_integration/     CPU+RAM·BUS+UART 연결 기록
├── 06_scenario_test/   PC 입력부터 LCD까지 시험
├── 07_final/           보고서·타이밍·시연 증빙
├── rtl/                SoC top·주소 디코더·어댑터 개발 위치
├── tb/                 SoC별 통합 TB 개발 위치
├── fpga/               SoC용 보드·제약·프로젝트 안내
├── firmware/           계산기 ROM 프로그램 개발 위치
├── pc_tools/           PC UART 도구 개발 위치
├── stm32/              수신·LCD 펌웨어 개발 위치
└── scripts/            원본 모듈 참조·단위 실행·프로젝트 생성
```

CPU 기본 데모와 DRAM 두 타이밍 설정에는 실행 PASS 근거가 있다. UART는 compile/elaboration과 자동 기능 시험을 구분한다. BUS·ROM 래퍼·SoC top·signed16 계산기 프로그램·PC 도구·STM32 LCD 펌웨어는 계속 후속 구현 단계다. 현재 검증 결과는 history와 단위 test.md를 따른다.

과거 CPU/RAM 결정 기록은 Windows C:/codex_project의 각 history에 보존한다. 기존 Sercurity는 별도 프로젝트다. 구성은 [logistics-automation](https://github.com/hwoo97/logistics-automation/tree/80bc1b80edac121d81cb52f1bc222814af64de7d)의 일곱 단계 구분을 SoC에 맞게 참고했다.
