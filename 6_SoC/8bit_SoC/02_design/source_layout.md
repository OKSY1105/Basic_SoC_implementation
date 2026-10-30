# 공용 모듈과 SoC의 소유 경계

`1_RTL/2_TINY_PROJECT`는 재사용 가능한 모듈과 단독 TB/도구의 원본이다. `6_SoC/8bit_SoC`는 필요한 원본을 골라 연결하고 통합 문서·프로그램·보드 구성을 관리한다. 이 구분은 사용자가 재확인한 의도다.

| 공용 원본(저장소 기준) | SoC 사용 방법 |
|---|---|
| 1_RTL/2_TINY_PROJECT/CPU/8bit_CPU | sources.json의 RTL/TB/include, 공용 Tcl에서 직접 참조 |
| 1_RTL/2_TINY_PROJECT/UART | UART 코어·단위 TB·보드 예제 원본 참조 |
| 1_RTL/2_TINY_PROJECT/DRAM | 행동 모델 참조, 합성 소스로 넣지 않음 |
| 1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER | 바이트 제어기와 단독 TB 참조 |
| 1_RTL/2_TINY_PROJECT/BUS | 재사용 BUS 구현 위치, 현재 계획 단계 |

SoC에 넣을 내용은 주소 디코더·UART MMIO 어댑터·ROM 래퍼·SoC top·통합 TB와 프로그램/PC/STM32 코드다. 공용 코어를 수정하면 그 원본 한 곳에만 적용한다. 복사본이나 소스 심볼릭 링크를 만들어 따로 관리하지 않는다.

`sources.json` 경로는 SoC 루트를 기준으로 해석한다. 예를 들어 CPU top은 `../../1_RTL/2_TINY_PROJECT/CPU/8bit_CPU/RTL/cpu8_top.v`다. `scripts/run_unit.py`와 `scripts/create_vivado.tcl`이 이 원본을 읽는다. GitHub에서도 원래 CPU 경로가 실제 폴더로 열린다.
