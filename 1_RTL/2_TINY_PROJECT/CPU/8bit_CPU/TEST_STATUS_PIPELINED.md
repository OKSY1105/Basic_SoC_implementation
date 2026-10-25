# CPU8 RTL 검증 결과 — 2026-10-25

새 코어의 top은 `cpu8_top`이다. 기존 `cpu_top`과 ISA가 다르며 원본 CPU/ 및 기존 TB는 변경하지 않았다.

| 검사 | 실제 결과 | 범위 / 한계 |
|---|---|---|
| Icarus Verilog 13.0 프로그램 회귀 | **PASS: 62개 프로그램, 1,509개 완료 명령** | 독립 Python ISA 모델과 명령 완료마다 GPR/X/FLAGS/PC/쓰기 추적, 메모리 부작용 대조 |
| 17개 opcode | 모든 명령 실행 확인 | 명령 실행 여부이며 전체 기능/코드/토글 커버리지 100%라는 뜻은 아님 |
| ALU 전수 시험 | **PASS: 786,432건** | ADD/ADC/SUB/SBC/CMP/AND × 256 × 256 × carry 2종, 결과와 Z/N/C/V |
| 메모리 대기 중 reset | **PASS** | 미완료 데이터 요청 취소, 이전 명령 응답 폐기, 재시작 |
| 기존 MIPS형 CPU 회귀 | **PASS** | 원본 TB, 2-cycle 메모리 지연; reads=189, writes=1, data[0x80]=30, PC=0x42 |
| Yosys 0.70 일반 논리 합성 | **PASS** | `synth -noabc`, `check -assert`, 래치 없음; FPGA 매핑/타이밍 결과 아님 |
| Vivado 2024.2 xvlog | **PASS** | 새 RTL 및 SystemVerilog TB 구문 분석 |
| Vivado xelab/XSIM 실행 | **환경 오류로 미완료** | xelab의 네이티브 C 컴파일 단계 XSIM 43-3409/43-3915 실패. XSim 시뮬레이션 통과로 기록하지 않음 |
| Vivado FPGA OOC 합성 | **환경 오류로 미완료** | Windows Vivado 실행기의 설치 폴더 pushd/초기화 접근 실패. 제공한 Tcl의 성공을 확인하지 못함 |
| FPGA 배치·배선·타이밍·실물 | **미실행** | 최종 보드/핀/클록/제약 미확정 |

프로그램 회귀는 25개 directed 프로그램의 무대기/지연 메모리 조건 50건과 고정 seed의 무작위 프로그램 12건이다.
R0 쓰기, RAW/WAW, carry/borrow, signed overflow, FLAGS/X 의존성, 분기 taken/not-taken/flush, 주소 경계/순환,
load-use, 잘못된 명령/예약 비트, 인출/데이터 오류 및 오래된 오류 우선순위, MMIO 부작용 1회 처리를 포함한다.
UART MMIO는 **시험용 모델**이며 실제 UART 직렬 신호/IP를 검증한 결과가 아니다.

`PROGRAMS/first_add.mem`의 `080A 0914 2401 0400` 실행에서 R0=30, R1=20이다.
무대기 TB에서는 reset 해제 후 7클록, 4개 완료 명령, stall 1클록, 3단계 동시 점유 1클록을 관찰했다.
이는 이 TB 조건의 측정이며 실제 FPGA의 Fmax나 모든 명령의 고정 3클록 실행을 의미하지 않는다.

재현 가능한 프로그램별 요약은 [VERIFICATION/cpu8_regression_results.json](VERIFICATION/cpu8_regression_results.json)에 있다.
시험 코드는 `TB/`와 `TOOLS/run_cpu8_tests.py`에 있으며 생성된 원시 로그/파형/도구 바이너리는 커밋하지 않는다.

```sh
python3 TOOLS/run_cpu8_tests.py --simulator iverilog
yosys -s TOOLS/check_cpu8.ys
```

Yosys는 YoWASP Yosys 0.70 (git 28ba3cb92)로 실행했다. ABC 임시파일 생성 제한 때문에 기술 매핑 전 `-noabc` 경로를 사용했다.
합성 후 일반 논리 셀 수는 계층 전체 1,237개이며 이 수치를 Xilinx LUT/FF 수로 해석하지 않는다.

실제 계산기용 signed 16bit 산술/문자열 변환/명령 파서 프로그램, 프로그램 ROM/2KiB RAM 래퍼,
UART IP 연결, STM32 LCD 드라이버는 다음 작업이다. CPU 단독 RTL의 통과를 전체 계산기 완성으로 기록하지 않는다.
