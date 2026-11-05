# Zybo Z7-20 보드 top과 빌드

## 보드 top — `soc8_zybo_top.v` (2026-11-05)

`soc8_top`(SoC 본체)을 Digilent Zybo Z7-20(`xc7z020clg400-1`)의 PL에 올리기 위한 연결층이다. PS(ARM)는 쓰지 않는다. 핀 제약은 [`soc8_zybo_z7_20.xdc`](../../constraints/soc8_zybo_z7_20.xdc), 포트·연결표는 [제약 README](../../constraints/README.md)에 있다.

| 부분 | 내용 |
|---|---|
| 클록 | `i_clk125`(K17, 125 MHz) → `MMCME2_BASE`(VCO = 125 × 8 = 1000 MHz, ÷10) → BUFG → 100 MHz. 되먹임도 BUFG를 거친다. IP를 만들지 않고 primitive를 직접 둔다 |
| reset | `soc8_top.i_rst_n` = `!i_btn_rst && locked`. `soc8_top` 안의 `reset_sync`가 바로 assert하고 100 MHz 클록에 맞춰 해제한다 |
| DRAM | [`dram_bram_model`](../../../../../1_RTL/2_TINY_PROJECT/DRAM/dram_bram_model.v)(M4)을 DRAM 제어기 core의 분리 핀에 FPGA 안에서 연결한다(3상태·FPGA 핀 없음). 모델과 SoC는 같은 100 MHz 클록을 쓴다(모델의 사용 조건) |
| UART | 115200 bps 8E1, Pmod JC(TX V15, RX W15). 보드 USB-UART는 PS 쪽이므로 외부 3.3 V USB-UART 변환기를 쓴다 |
| LED | LD0 reset 해제, LD1 DRAM 초기화 완료, LD2 CPU halt, LD3 CPU fault. 계산기 실행 중에는 LD0·LD1이 켜지고 LD2·LD3은 꺼져 있다. 나머지 디버그 출력은 연결하지 않는다 |
| ROM | `ROM_FILE` = 계산기 펌웨어 이미지(`calc.mem`). 빌드 스크립트가 `firmware/calc.asm`을 어셈블해 넘긴다 |

## 보드 TB — `tb/board/tb_soc8_zybo_top.sv`

보드 top을 핀으로만 시험한다: 125 MHz 클록 → MMCM(unisim 모델) → SoC, BTN0, 115200 bps 8E1 UART, LED.

```sh
bash 6_SoC/8bit_SoC/scripts/run_zybo_top_tb.sh /tmp/zybo_top_tb    # 저장소 루트 기준(WSL). 종료 코드 0 = PASS
```

| 실행 | ROM 이미지 | 판정 |
|---|---|---|
| `calc` (`PROG=0`) | 계산기 펌웨어 | MMCM 출력 주기 10.000 ns, BTN0 동안 LD0·LD1 꺼짐과 해제 뒤 켜짐, LD2·LD3 꺼짐 유지, `calculator.md` 5절 사례(오류 4종, 17바이트 DIV 응답, `ERR RANGE` 뒤 A·B 유지)를 규약의 속도 규칙대로 보내 응답 비교, 중간 BTN0 reset 뒤 `ERR NOARG`, 모든 송신 프레임의 parity·stop bit |
| `ram` (`PROG=1`) | `tb/soc/programs/ram_basic.asm` | 256바이트(캐시의 4배)를 캐시·DRAM 제어기·BRAM 모델로 쓰고 읽어 UART `80 12 34 56 78` → HALT(LD2 켜짐, LD3 꺼짐), BRAM 모델 배열 256바이트 = 3 + 7i |

계산기 펌웨어는 RAM 변수 25바이트를 모두 캐시 안에 두고 읽기 전에 항상 쓰므로, DRAM에서 돌아오는 데이터를 쓰지 않는다. 그래서 DRAM 경로는 `ram` 실행으로 확인한다(아래 변이 시험의 `dram_dq_loop`).

결과 (2026-11-05, WSL Vivado 2024.2 XSim):

```text
== calc
CLOCK soc_period_ns=10.000 locked=1
COVER mode=calc lines=25 replies=17 tx_bytes=200 resets=2
BOARD_TOP_PASS mode=calc lines=25 replies=17 tx_bytes=200 resets=2
== ram
CLOCK soc_period_ns=10.000 locked=1
COVER mode=ram tx_bytes=5 resets=1 dram_bytes_checked=256
BOARD_TOP_PASS mode=ram tx_bytes=5 resets=1
RESULT status=0
```

변이 시험(임시 사본의 `soc8_zybo_top.v` 한 줄 변경, 모두 FAIL):

| 변이 | 첫 FAIL |
|---|---|
| MMCM 출력 ÷8(125 MHz) | 두 실행 `FAIL SoC clock period 8.000000 ns, expected 10.000` |
| reset 극성 반대 | 두 실행 `FAIL LED[0] not 0 while BTN0 is pressed` |
| DRAM 데이터 입력을 core 자기 출력에 연결 | `calc`는 PASS(위 설명), `ram` `FAIL ram_basic: UART byte 0 = 00, expected 80` |
| LD2·LD3 뒤바꿈 | `calc`는 PASS(둘 다 꺼짐), `ram` `FAIL LED[3]: CPU fault` |

- 처음 판의 TB는 `calc` 실행만 있어 `dram_dq_loop` 변이를 놓쳤다(PASS). 그래서 `ram` 실행을 추가했다.

## bitstream 빌드와 배치·배선 결과 (PPA)

```sh
bash 6_SoC/8bit_SoC/scripts/build_zybo.sh /tmp/zybo_build    # 저장소 루트 기준(WSL). bitstream: /tmp/zybo_build/soc8_zybo_top.bit
```

`scripts/build_zybo.tcl`이 합성 → `opt_design` → `place_design` → `phys_opt_design` → `route_design` → 보고서 → bitstream을 실행한다(non-project batch). latch·조합 loop가 있거나, M4 배열이 BRAM이 아니거나, 배선 뒤 setup·hold가 하나라도 음수이면 중단한다.

결과 (2026-11-05, WSL Vivado 2024.2):

```text
SOC8_ZYBO_BUILD_PASS part=xc7z020clg400-1 lut=1012 ff=981 bram=3 lutram=69 bufg=2 mmcm=1 wns_ns=0.558 whs_ns=0.034 power_total_w=0.228 power_dynamic_w=0.120 power_static_w=0.108
critical_warnings=0
```

| 항목 | 값 |
|---|---|
| 면적 | LUT 1,012 (1.90%), FF 981 (0.92%), BRAM 3 (RAMB36: ROM 2 + DRAM 모델 1, 2.14%), LUT as memory 69, DSP 0, I/O 8, BUFG 2, MMCM 1 |
| 성능 | 100 MHz 제약에서 WNS +0.558 ns, TNS 0, WHS +0.034 ns, 모든 timing 제약 충족(timing endpoint 2,968). 여유로 환산한 최고 주파수 추정 약 106 MHz(1 / (10 − 0.558) ns, 같은 클록 하나 기준) |
| 전력 | 총 0.228 W(동적 0.120 W, 정적 0.108 W), 접합 온도 27.6 °C. Vivado 기본 활동률(vectorless) 추정이며 신뢰도 Medium이다. 보드 측정값이 아니다 |
| 클록 | `sys_clk_pin` 125 MHz(입력), `w_clk100_mmcm` 100 MHz(SoC), `w_clkfb_mmcm` 125 MHz(되먹임) |

- `check_timing`: 제약이 없는 내부 끝점 0. 입력 지연이 없는 입력 2개(`i_btn_rst`, `i_uart_rxd`)와 출력 지연이 없는 출력 5개(`o_uart_txd`, `o_led[3:0]`)는 모두 XDC의 `set_false_path` 대상이다.
- DRC 경고 `REQP-1839`(RAMB36 async control check): 한 건은 (BRAM 제어 핀, 그 핀에 닿는 비동기 reset 레지스터) 한 쌍이다. DRC 보고서는 규칙마다 20건까지만 적으므로(`CHECK-3` Report rule limit reached) 20건만 나오며, 모두 ROM BRAM `u_soc/u_rom/r_a_data_reg_0`의 `ADDRARDADDR[14]` 한 핀에 대한 것이다(구동 레지스터: 캐시 상태·주소·valid, ROM 오류, UART IRQ). 배선된 checkpoint에서 BRAM 제어 핀(주소·enable·write enable·reset)의 입력 쪽을 따라가면, 실제 비동기 reset을 쓰는 레지스터가 조합 논리를 거쳐 닿는 핀은 ROM BRAM 2개(`r_a_data_reg_0`·`_1`)의 `ADDRARDADDR`·`ENARDEN`·`ENBWREN` 핀 각 14개다. 구동 레지스터는 캐시·버스·APB 브리지·UART·ROM·`reset_sync`에 있다. 명령 인출 주소와 ROM 선택이 이 레지스터들에서 같은 클록 안에 조합으로 정해지기 때문이다. M4 BRAM에는 해당 핀이 없다(Vivado power 최적화가 넣은 플립플롭은 CLR이 GND다). 경고 내용은 reset이 assert될 때 메모리 내용이나 읽은 값이 깨질 수 있다는 것이다. ROM BRAM의 write enable은 상수 0이므로 내용이 바뀌지 않고, reset 동안 읽은 값은 CPU도 reset 중이라 쓰이지 않는다. 그래서 이 설계에서는 영향이 없다고 판단해 두었다. `PDRC-138/142/144/146` 5건은 같은 slice의 LUT 쌍 배치 경고다.
- 합성 단계 추정(`rtl/soc/README.md`, `soc8_top` OOC)은 LUT 994·WNS +0.459 ns였다. 보드 top은 MMCM·M4가 더해지고 배치·배선 뒤 값이다.

## 보드에 올리기

WSL에는 USB(JTAG) 연결이 없으므로 이 단계는 Windows Vivado Hardware Manager에서 한다.

1. bitstream을 저장소 밖의 영구 폴더에 빌드한다: `bash 6_SoC/8bit_SoC/scripts/build_zybo.sh /home/sean/zybo_build`. Windows에서는 `\\wsl.localhost\Ubuntu-22.04\home\sean\zybo_build\soc8_zybo_top.bit`로 연다. WSL 배포판은 실행 중인 프로세스가 없으면 곧 멈추고, 다시 시작할 때 `/tmp`를 비운다(systemd `tmpfiles`의 `/tmp` 규칙). 그래서 `/tmp`에 둔 bitstream은 Windows에서 열 때 이미 없을 수 있다.
2. 배선: USB-UART 변환기의 TX → FPGA RX(W15), RX → FPGA TX(V15), GND → Pmod GND. 3.3 V 변환기만 쓴다. 커넥터 핀 번호는 Zybo Z7 참조 설명서로 확인한다.
3. 보드에 SD·QSPI 부팅 이미지가 있으면 PS가 PL을 다시 구성할 수 있으므로, 부팅 모드 점퍼(JP5)를 JTAG로 두기를 권장한다(참조 설명서로 확인).
4. 보드의 PROG/UART micro-USB(J12)를 PC에 연결하고 전원을 켠 뒤, Windows PowerShell에서 아래를 실행한다. [`scripts/program_zybo.ps1`](../../../scripts/program_zybo.ps1)이 Windows Vivado를 batch로 실행한다([`scripts/program_zybo.tcl`](../../../scripts/program_zybo.tcl)). JTAG에서 xc7z020 장치 하나를 찾아(ARM DAP는 건너뜀) bitstream을 쓰고 DONE을 확인한다. 성공하면 `SOC8_ZYBO_PROGRAM_PASS`와 `RESULT status=0`이 나온다. 다른 bitstream·Vivado 경로는 `-Bit`·`-VivadoBin`으로 준다. GUI로 할 때는 Vivado → Open Hardware Manager → Open Target → Auto Connect → Program Device에서 같은 `.bit`를 고른다.

   ```powershell
   powershell -ExecutionPolicy Bypass -File \\wsl.localhost\Ubuntu-22.04\home\sean\Basic_SoC_implementation\6_SoC\8bit_SoC\scripts\program_zybo.ps1
   ```

5. 확인: LD0·LD1 켜짐, LD2·LD3 꺼짐. PC 터미널을 115200 bps, 8 데이터 bit, even parity, stop 1로 열고 `10,20` Enter → `ADD` Enter를 보내면 `ADD:30`이 와야 한다. BTN0을 누르면 reset된다.

작업 PC의 Windows Vivado 2024.2는 합성이 실패한 기록이 있어 합성·구현은 WSL에서 한다. Hardware Manager batch 실행은 2026-11-05에 보드를 연결하지 않은 상태로 확인했다: UNC 경로의 Tcl·bitstream 읽기, hw_server 기동, JTAG 대상 0개 오류와 `RESULT status=1`. 장치를 찾은 뒤의 쓰기·DONE 확인은 보드를 연결해 처음 실행할 때 확인한다.

## 기존 Zybo UART 보드 래퍼 참조

원본은 [1_RTL 공용 라이브러리](../../../../../1_RTL/2_TINY_PROJECT/UART/zybo_uart_top.v)에 있다. 이 SoC는 원본을 직접 읽으며 같은 모듈의 사본이나 심볼릭 링크를 이곳에 두지 않는다.

SoC용 연결 회로·제약·통합 TB를 추가할 때만 이 폴더에 새 파일을 작성한다. 단위 실행은 sources.json, 프로젝트 생성은 scripts/create_vivado.tcl의 공용 모듈 경로를 사용한다.
