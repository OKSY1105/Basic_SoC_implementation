# CORE-5300 (`XC7Z010CLG400-1`) 스마트 방범 시스템 Verilog RTL

## 온보드 USB UART 실기 실행 — 2026-10-29

**온보드 USB는 PS UART0(MIO14/15) → ARM 브릿지 → PS UART1(EMIO) → Verilog로 연결된다.** `security_core5300.xpr`의 GPIO UART(G14/G15) 구성과 용도가 다르다. USB 사용은 다음 진입점을 사용한다.

1. `RUN_USB_UART.bat`: Zynq PS+PL 빌드·ARM 컴파일·JTAG 실행. `RUN_USB_UART.bat OUTPUT_DIR`로 별도 결과 폴더를 지정할 수 있다.
2. `../pc_gui/RUN_UART_UI.bat`: 현재 PC의 Python 3.9로 UI 실행 후 COM9/9600bps 연결.
3. 접속 시 CMD `read`로 현재 거리·임계치·경보 상태를 가져온다. 이미 연결돼 있으면 `상태 요청` 버튼을 사용한다. 임계치는 평소에는 스위치 변경 때 한 번만 보내고 요청 때 다시 보낸다.
4. STOP 성공 표시는 실제 `PW:OK_PC` 응답을 받은 뒤에 나온다. 응답이 없으면 `보드 정지 미확인`으로 표시한다. STOP 이후에도 거리 측정과 UART 스트리밍은 계속된다.

전원을 다시 켜면 ARM 브릿지를 다시 실행해야 한다. 비트스트림만 올리면 온보드 USB 통신이 되지 않는다. 상세 원인·검증은 [HIST-16](<../history.md#h016>)을 따른다.


> **2026-10-29 현행 안내**: 최신 동작과 시험 근거는 [HIST-15](<../history.md#h015>)를 따른다. 아래의 초기 설계 설명과 다른 부분은 이 안내를 우선한다.

## 현재 동작과 시뮬레이션

- 거리는 모든 스위치 OFF 및 경보 상태에서도 매초 전송한다. 100cm 이상 및 센서 타임아웃은 `Distance:0000`, 100cm 미만은 `Distance:0023`과 같은 형식이다. 5회 이동평균을 사용하며 스위치는 침입 경보 임계치만 바꾼다.
- `vivado_proj/security_core5300.xpr`를 열어 **Run Behavioral Simulation**을 실행한다. `lcd_ctrl.v`를 등록했고 기본 8개 검사를 끝까지 실행하도록 설정했다.
- 기존 프로젝트에서 소스 누락이 있으면 Tcl Console에 `source C:/Antigravity_project/Sercurity/fpga_rtl/repair_sim_project.tcl`을 실행한다. 새 프로젝트는 `create_vivado_project.tcl`로 만든다.
- 추가 거리 회귀는 `tb_distance_stream.sv`의 `tb_distance_review`를 Simulation Top으로 선택한다. 스위치 OFF·99/100cm·무응답·고착·복구와 UART 프레임 CRC를 확인한다.

## 생성 결과를 지운 상태에서 FPGA·ARM 재빌드

PowerShell에서 이 `fpga_rtl` 폴더를 기준으로 실행한다. 결과는 `build/`에 새로 생성되며 소스와 구분한다.

```powershell
& 'C:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch -source build_zynq_soc.tcl
& .\compile_arm.bat
# JTAG 다운로드는 위 두 빌드가 끝난 후에만 실행
& .\RUN_JTAG.bat
```

SD 부팅 파일이 필요한 경우에는 아래 단계를 추가한다.

```powershell
& 'C:\Xilinx\Vitis\2024.2\bin\xsct.bat' build_fsbl.tcl
& 'C:\Xilinx\Vitis\2024.2\bin\bootgen.bat' -image bootimage.bif -arch zynq -o build/BOOT.bin -w on
```

`rebuild_bitstream.tcl`은 같은 빌드 절차를 사용한다. `build_zynq_soc.tcl`은 `-tclargs OUTPUT_DIR`, `compile_arm.bat`과 `build_fsbl.tcl`은 첫 번째 인수로 별도 출력 폴더를 받을 수 있다. JTAG 기본 입력은 `build/security_top_zynq.bit`, `build/uart_bridge.elf`, `build/ps7_init.tcl`이다.

## 원본 백업 및 보관된 결과

수정 전 원본은 [ZIP 백업](<../backup_before_uart_fix_20261029/Sercurity_original.zip>)과 [파일 해시 목록](<../backup_before_uart_fix_20261029/manifest.json>)에 있다. 현재 폴더에서는 생성 결과를 제거했으며 `.v/.sv`, `.tcl`, `.xdc`, C/어셈블리/링커 입력, 배치/BIF, GUI 및 XPR/WCFG 설정을 보존했다. 삭제된 오래된 결과에 대한 과거 history 링크는 ZIP 보관 지문으로 검증한다. 최신 변경은 보드에 다운로드하지 않았다.

## 초기 설계 참고 — 아래는 2026-10-27 문서


기존 ATmega128 스마트 방범 시스템을 **CORE-5300 FPGA 실습장비(`XC7Z010CLG400-1`, PL `50MHz`)**로 이식한 Verilog RTL 설계 및 검증 파일 모음입니다.

---

## 1. 확정된 시스템 동작 사양 (모드 전환 제거 · 상시 감시)

1. **상시 감시 + 디지털 시계 (`F-01`, `NFR-03`)**:
   - 전원 인가 또는 리셋(`PB0`, `V15`) 시 별도의 모드 전환 스위치 없이 **즉시 상시 초음파 감시 상태**로 동작합니다.
   - 평소 4자리 7-세그먼트(`U12, T12, T10, T11` Active High / `Y16~V13` Active Low)에는 24시간제 디지털 시계(`HH.MM`)를 2ms 다이나믹 스캔으로 표시합니다.
2. **동적 임계 거리 설정 (`F-02`)**:
   - 슬라이드 스위치 4개(`PL SW[3:0]`: `W14, Y14, T16, U17`)로 임계 거리(`threshold_cm`)를 실시간 설정합니다.
   - 계산식: `threshold_cm = 10 + (SW[3:0] × 5)` cm (`10cm ~ 85cm`, `5cm` 단위)
3. **50ms 초음파 거리 측정 + 5회 이동평균 필터 (`F-02`, `NFR-01`, `NFR-05`)**:
   - `50ms` 주기(`NFR-01` 100ms 이내 충족)로 `Trig`(`J20`)에 `10us` 펄스를 출력하고 `Echo`(`H20`) 폭을 `1us` 단위로 측정(`/ 58` → cm 환산)합니다.
   - 최근 **5회 유효 측정값의 이동평균(`sum / 5`)**으로 침입 여부를 판정하여 단발성 센서 노이즈로 인한 오경보를 방지합니다(예외 시나리오 3 충족).
4. **복합 경보 출력 및 알람 Latch 유지 (`F-03`)**:
   - `distance_cm <= threshold_cm` 감지 시 **`alert_flag = 1`로 고정(Latch)**되며, 침입자가 물러나 거리가 다시 멀어져도 스스로 꺼지지 않습니다.
   - 경보 작동 시:
     - **PL LED 0~3 (`P15, P16, N20, P20`)**: `250ms` 주기로 전체 점멸(`4'b1111` ↔ `4'b0000`)
     - **부저 (`L19`)**: 경보음 출력
     - **DC 모터 (`DRV8848`: `IN1=K14`, `IN2=J14`, `nSleep=L14`)**: `nSleep=1`, `IN2`에 `1kHz` PWM(듀티비 75%) 구동
5. **알람 해제 수단 (`F-04`, `F-05`, `NFR-02`, `NFR-04`)**:
   - **로컬 해제 (`1x4 정전식 터치 키패드 TTP224`: `L15, K16, J16, M17`)**:
     - 각 키에 **20ms 하드웨어 디바운서(`NFR-04`)** 및 상승 엣지 검출기를 적용했습니다.
     - `1번(L15) → 2번(K16) → 3번(J16) → 4번(M17)` 순서로 누르면 단계별로 `PW:STEP1~3`을 송신하고 4단계 완료 시 알람을 해제(`PW:OK_NRM`)한 뒤 상시 감시로 복귀합니다.
     - 잘못된 순서로 입력하면 즉시 `pw_step = 0`으로 초기화하고 알람을 유지하며 PC로 `PW:ERROR`를 전송합니다(예외 시나리오 1 충족).
   - **원격 해제 (PC Python GUI `UART1_Repeater_GUI.py` 연동)**:
     - `[SOF(0xAA)] + [TYPE(1B)] + [LEN(1B)] + [PAYLOAD] + [CRC8(1B)]` 프레임 규격과 1바이트 XOR 체크섬(`NFR-02`)을 하드웨어로 구현했습니다.
     - PC에서 `"stop"`(또는 `"STOP"`) 명령 수신 시 CRC8이 일치하면 즉시 알람을 해제하고 `ACK("OK")` 및 `DATA("PW:OK_PC")`를 반환합니다.
     - CRC8 오류 시 명령을 무시하고 `ERR("E:CRC")` 프레임을 반환합니다(예외 시나리오 2 충족).

---

## 2. 모듈 구성 및 파일 목록

| 파일명 | 역할 | 관련 요구사항 |
| :--- | :--- | :--- |
| [security_top.v](<security_top.v>) | 최상위 통합 모듈 (`XC7Z010CLG400-1` 포트 매핑) | 전체 |
| [clk_div.v](<clk_div.v>) | `50MHz` 클럭 분주기 (`1us`, `2ms`, `50ms`, `1s` 틱 생성) | `F-01`, `NFR-01` |
| [debounce_edge.v](<debounce_edge.v>) | 2-FF 동기화기 + `20ms` 하드웨어 디바운서 + 원샷 엣지 검출기 | `NFR-04` |
| [clock_fnd_ctrl.v](<clock_fnd_ctrl.v>) | 24시간제 디지털 시계(`HH:MM`) 및 4자리 7-Segment 다이나믹 컨트롤러 | `F-01`, `NFR-03` |
| [ultrasonic_ctrl.v](<ultrasonic_ctrl.v>) | `50ms` 주기 초음파 거리 측정기 + **5회 이동평균 필터** | `F-02`, `NFR-01`, `NFR-05` |
| [security_fsm.v](<security_fsm.v>) | 상시 감시·알람 Latch·터치 키패드 비밀번호 FSM·복합 경보 제어기 | `F-02`, `F-03`, `F-05` |
| [uart_frame_ctrl.v](<uart_frame_ctrl.v>) | `9600bps` UART RX/TX 및 `0xAA` 프레임/CRC8 파서·패킷 빌더 | `F-04`, `NFR-02` |
| [security_core5300.xdc](<security_core5300.xdc>) | CORE-5300 보드 핀 제약 파일 (`LVCMOS33`, 34개 물리 핀 고정, `uart_rx` 내부 `PULLUP`) | 하드웨어 핀맵 |
| [tb_security_top.v](<tb_security_top.v>) | **1단계(Behavioral RTL Sim)** 전 요구사항(Check 1~8) 자가 검증 테스트벤치 | 1단계 기능 시뮬레이션 |
| [tb_post_synth.v](<tb_post_synth.v>) | **3단계(Post-Synthesis Gate-Level Sim)** 최상위 물리 핀 전용 넷리스트 검증 테스트벤치 | 3단계 게이트 레벨 시뮬레이션 |
| [create_vivado_project.tcl](<create_vivado_project.tcl>) | Vivado 2024.2 프로젝트 자동 생성 스크립트 | 프로젝트 생성 |
| [open_sim_gui.tcl](<open_sim_gui.tcl>) | Vivado 2024.2 GUI 실행 · 6대 기능별 파형 그룹 구성 · 전 구간 시뮬레이션 자동 실행 스크립트 | GUI 파형 확인 |
| [run_vivado_verify.tcl](<run_vivado_verify.tcl>) | Vivado 2024.2 2단계(합성·구현·타이밍·비트스트림) & 3단계 넷리스트 자동 검증 스크립트 | 배치 검증 |

---

## 3. 5단계 검증 절차 및 Vivado 2024.2 실측 검증 결과

| 단계 | 검증 항목 | 사용 파일 / 도구 | 실측 결과 |
| :--- | :--- | :--- | :--- |
| **1단계** | **RTL 기능 시뮬레이션 (Behavioral Sim)** | [tb_security_top.v](<tb_security_top.v>) (`xvlog` / `xelab` / `xsim`) | **PASS** (`ALL 8 CHECKS PASSED, 0 errors`) |
| **2단계** | **Vivado 합성 · 구현 · 타이밍 · 비트스트림 생성** | [run_vivado_verify.tcl](<run_vivado_verify.tcl>) (`synth_design` → `route_design` → `write_bitstream`) | **PASS** (`LUT 863(4.90%)`, `FF 599(1.70%)`, `Latch 0`, **`WNS +5.067ns`**, `0 DRC error`) |
| **3단계** | **합성 후 게이트 레벨 시뮬레이션 (Post-Synthesis Sim)** | [tb_post_synth.v](<tb_post_synth.v>) + `UNISIM` 게이트 넷리스트 (`glbl`) | **PASS** (`ALL 5 GATE-LEVEL CHECKS PASSED`, `uart_tx` 51개 `0xAA` 프레임 CRC8 일치) |
| **4단계** | **CORE-5300 보드 단독 하드웨어 검증** | `security_top.bit` 다운로드 + 보드 실물 스위치/센서/터치/모터 | 보드 연결 시 즉시 수행 가능 |
| **5단계** | **PC Python GUI 통합 검증** | [../pc_gui/UART1_Repeater_GUI.py](<../pc_gui/UART1_Repeater_GUI.py>) (`9600bps`) | 보드 연결 시 즉시 수행 가능 |

> **3단계(Post-Synthesis Simulation) 핵심 주의사항**:
> 합성 후 생성되는 게이트 레벨 넷리스트(`security_top`)는 내부 계층 신호(`dut.alert_flag` 등)와 최상위 `parameter` 오버라이드가 제거되고 Xilinx `UNISIM` 프리미티브(`LUT`, `FDRE`, `CARRY4`, `IBUF`, `OBUF`)로 변환됩니다. 따라서 3단계 합성 후 시뮬레이션에서는 반드시 **최상위 물리 핀만 제어·관측하고 `uart_tx` 직렬 파형을 디코딩하는 전용 테스트벤치([tb_post_synth.v](<tb_post_synth.v>))**를 시뮬레이션 Top으로 설정해야 합니다.

---

## 4. Vivado 프로젝트 생성 및 보드 연결 방법

### 4-1. Vivado 프로젝트 자동 생성

Vivado 실행 후 하단 **Tcl Console**에서 아래 두 줄을 실행하면 프로젝트 생성과 파일 등록이 한 번에 완료됩니다.

```tcl
cd C:/Antigravity_project/Sercurity/fpga_rtl
source create_vivado_project.tcl
```

### 4-2. 보드 하드웨어 스위치 설정 및 USB-UART 연결 참고

1. **보드 물리 스위치 2곳 확인**:
   - **카메라 vs 센서/모터 선택 스위치**: 반드시 **센서/모터** 방향으로 설정
   - **DC 모터 vs 스텝 모터 선택 스위치**: 반드시 **DC 모터** 방향으로 설정
2. **PC ↔ CORE-5300 보드 USB-UART 케이블 연결 참고**:
   - CORE-5300 보드의 내장 USB-UART 포트는 Zynq 칩의 **PS(ARM) 영역 핀(`MIO 14, 15`)**에 배선되어 있습니다(교재 **학습 5-1, p.319**).
   - 순수 PL 프로젝트만으로 바로 시험할 때는 [security_core5300.xdc](<security_core5300.xdc>)의 예비 PL 핀(`G15` RX [`PULLUP true`], `G14` TX)에 USB-TTL을 연결하거나, 보드 내장 USB 케이블(`MIO 14, 15`)을 그대로 쓸 때는 Vivado Block Design에서 Zynq7 PS IP의 UART 브릿지를 연결하여 사용합니다.
   - PC에서는 [../pc_gui/UART1_Repeater_GUI.py](<../pc_gui/UART1_Repeater_GUI.py>)를 실행하여 실시간 거리/임계거리 모니터링과 `STOP` 원격 해제를 수행합니다.
