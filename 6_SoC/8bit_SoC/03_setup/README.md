# 환경 준비와 실행

작업 저장소는 WSL Ubuntu-22.04의 `/home/sean/Basic_SoC_implementation`, 프로젝트는 `6_SoC/8bit_SoC`다. Windows에서는 `\\wsl.localhost\Ubuntu-22.04\home\sean\Basic_SoC_implementation\6_SoC\8bit_SoC`로 연다.

## 파일/경로 검사

```sh
cd /home/sean/Basic_SoC_implementation/6_SoC/8bit_SoC
python3 scripts/check_layout.py
```

## 단위 검증

기존 환경의 Vivado 2024.2 경로를 예시로 썼다. 설치 위치가 다르면 인자를 바꾼다. 기본 CPU/DRAM TB에는 PC 숫자 입력이나 CASES 파일이 필요 없다.

```sh
python3 scripts/run_unit.py all --vivado-bin /home/sean/Vivado/2024.2/bin
python3 scripts/run_unit.py cpu --vivado-bin /home/sean/Vivado/2024.2/bin
python3 scripts/run_unit.py ram --vivado-bin /home/sean/Vivado/2024.2/bin
```

CPU는 기본 데모, RAM은 기본·대체 타이밍 self-check를 실행한다. UART 항목은 기존 RTL/TB와 보드 래퍼 compile/elaboration만 수행한다. UART 기존 TB는 $stop을 사용하므로 자동 기능 PASS 근거로 표시하지 않는다. 전체 CPU 회귀는 CPU 패키지의 `TOOLS/run_cpu8_tests.py`를 별도로 이용한다.

## Vivado GUI 프로젝트 생성

원본 RTL을 직접 참조하며 기존 imported 사본을 재사용하지 않는다. part는 최종 보드에 맞춰 명시한다. 아래의 part는 Zynq-7020 예시이며 이번에 보드가 확정된 것은 아니다.

```sh
/home/sean/Vivado/2024.2/bin/vivado -mode batch -source scripts/create_vivado.tcl -tclargs cpu xc7z020clg400-1
```

`cpu`, `ram`, `uart` 중 하나를 선택한다. 생성된 프로젝트는 `build/vivado_<블록>/` 아래에 있으며 자동 Run Simulation/합성/보드 programming은 하지 않는다. GUI에서 simulation top을 확인하고 Run Behavioral Simulation을 실행한다.

최종 보드/FPGA part·입력 클록·핀·전압·baud는 실물 통합 전에 확인한다. 기존 Zybo XDC는 보드 예제로 보관한다. [이동 표와 기존 경로 호환](migration.md)을 참고한다.
