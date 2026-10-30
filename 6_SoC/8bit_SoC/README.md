# 8bit SoC — CPU·RAM·UART·BUS 통합 프로젝트

PC가 UART로 두 수와 연산을 보내면 FPGA의 8bit CPU가 계산하고 UART로 결과를 전송해 STM32의 LCD에 표시하는 시스템이다. 이 폴더는 그 시스템의 기획·설계·구현·검증 진입점이다.

## 읽는 순서

1. [현재 상태와 다음 작업](history.md#current)
2. [프로젝트 개요](01_planning/overview.md)와 [단계별 완료 기준](PROCESS.md)
3. [시스템 설계](02_design/README.md), 특히 [공유 인터페이스](02_design/interfaces.md)
4. [환경 준비와 실행 방법](03_setup/README.md)
5. 해당 블록의 [단위 검증 기록](04_unit/README.md)

## 구성

```text
8bit_SoC/
├── 01_planning/        목표·범위
├── 02_design/          CPU·RAM·UART·BUS·통합 계약
├── 03_setup/           도구·보드 준비
├── 04_unit/            블록별 시험 계획·결과
├── 05_integration/     CPU+RAM → BUS+UART 통합
├── 06_scenario_test/   PC 입력부터 LCD까지 시험
├── 07_final/           보고서·타이밍·시연 증빙
├── rtl/
│   ├── cpu/8bit_CPU/   기존 CPU 패키지(RTL/TB/TOOLS/PROGRAMS 포함)
│   ├── ram/           바이트 접근 DRAM 제어기
│   ├── uart/          UART·FIFO·baud generator
│   ├── bus/           주소 디코더·어댑터 개발 위치
│   ├── rom/           프로그램 ROM 래퍼 개발 위치
│   └── soc/           SoC top 개발 위치
├── sim/models/DRAM/    기존 행동 DRAM 모델(실제 FPGA RAM과 구분)
├── tb/                RAM·UART 및 향후 BUS/SoC TB
├── fpga/              Vivado 프로젝트·보드 래퍼·제약
├── firmware/          계산기 ROM 프로그램 개발 위치
├── pc_tools/          PC UART 송신 도구 개발 위치
├── stm32/             UART 수신·LCD 펌웨어 개발 위치
└── scripts/           경로 검사·단위 실행·Vivado 프로젝트 생성
```

단계 폴더는 설명과 검증 기록을 보관하고, 실제 코드는 `rtl/`, `tb/`, `firmware/`, `pc_tools/`, `stm32/`에서 관리한다. CPU 패키지 내부는 기존 도구가 사용하는 배치를 유지했다. 기존 Vivado 프로젝트의 imported 소스는 당시 사본이며, 새 프로젝트는 `scripts/create_vivado.tcl`로 현행 소스를 직접 참조해 만든다.

## 현재 상태

| 단계 | 상태 | 근거/다음 |
|---|---|---|
| 기획 | 기존 목표 인계 | signed8 입력·signed16 결과·정수 몫/나머지 |
| 시스템 설계 | 진행 중 | BUS·ROM·UART MMIO·통신 패킷 미확정 |
| 준비 | WSL Vivado 2024.2 사용 근거 있음 | 최종 FPGA 보드/핀/클록 확인 필요 |
| 단위 개발 | CPU·DRAM 기존 구현, UART 기존 RTL | 이번 실행 결과는 각 test.md에 기록 |
| 통합 | 미구현 | CPU+RAM 최소 연결부터 |
| 시나리오 시험 | 미실행 | PC→FPGA→STM32 LCD 전체 |
| 최종 결과 | 미완료 | 합성·타이밍·보드 시연 증빙 필요 |

[현행 소스 목록](sources.json)에는 실제 존재하는 파일만 등록한다. BUS·ROM·SoC·계산기 프로그램·PC 도구·STM32 폴더는 후속 작업 자리이며 구현 완료를 뜻하지 않는다.

## 기존 경로와 기록

- 실제 코드 원본은 이 폴더 아래로 이동했다. 기존 `1_RTL/2_TINY_PROJECT` 경로에는 상대 심볼릭 링크를 남겼다. [이동 표](03_setup/migration.md) 참고.
- CPU/RAM의 과거 결정 원본은 Windows `C:/codex_project/8bit_CPU/history.md`, `C:/codex_project/RAM/history.md`에 보존한다. 이곳의 history는 통합 프로젝트와 경로 개편 기록이다.
- 기존 `6_SoC/Sercurity`는 별도 프로젝트다.

## 구성 참고

[hwoo97/logistics-automation](https://github.com/hwoo97/logistics-automation/tree/80bc1b80edac121d81cb52f1bc222814af64de7d)의 기획→설계→준비→단위 개발→통합→시나리오 시험→최종 결과 구분을 SoC에 맞게 적용했다. ROS 2·AGV 코드와 교수 전용 절차는 가져오지 않았다.
