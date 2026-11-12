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

## 보드에 올리기 (Ubuntu)

빌드부터 프로그래밍·계산기 시험까지 모두 Ubuntu(WSL2) 터미널에서 한다(2026-11-09 사용자 결정). WSL2는 USB를 직접 보지 못하므로 host에 설치된 usbipd-win이 USB 장치를 WSL로 넘긴다. 이 호출은 [`scripts/wsl_usb.sh`](../../../scripts/wsl_usb.sh)가 Ubuntu에서 `usbipd.exe`를 불러 처리한다. 명령은 저장소 루트 기준이다.

처음 한 번만 하는 준비:

1. JTAG 케이블의 USB 장치 파일(`/dev/bus/usb/…`)에 일반 사용자가 쓸 수 있어야 한다(Vivado `hw_server`가 사용자 권한으로 실행되기 때문). `program_zybo.sh`가 보드를 붙인 뒤 확인하고, 쓸 수 없을 때만 아래 설치 명령을 안내하고 멈춘다. 작업 PC는 기존 PlatformIO udev 규칙(`/etc/udev/rules.d/99-platformio-udev.rules`의 FTDI `0403:60[01][104]` → 0666)이 Zybo(`0403:6010`)에 적용되어 이미 쓸 수 있으므로 설치하지 않는다. 권한이 없는 PC에서는 Xilinx 케이블 규칙을 한 번 설치한다(sudo 암호 필요). 이 명령은 규칙 파일 3개(Digilent·Xilinx FTDI·Platform Cable USB 장치를 모드 666으로)를 `/etc/udev/rules.d`에 복사만 하며, 되돌릴 때는 `sudo rm /etc/udev/rules.d/52-xilinx-*.rules`를 실행한다.

   ```sh
   cd /home/sean/Vivado/2024.2/data/xicom/cable_drivers/lin64/install_script/install_drivers && sudo ./install_drivers
   ```

2. 새 USB 장치는 usbipd-win에 한 번 등록(share)해야 처음 붙일 수 있다. 등록에는 host 관리자 권한이 필요하다(관리자 PowerShell: `usbipd bind --busid <BUSID>`, BUSID는 `bash 6_SoC/8bit_SoC/scripts/wsl_usb.sh list`로 확인). 작업 PC의 Zybo(`0403:6010`)는 이미 등록되어 있다. USB-UART 변환기는 처음 꽂을 때 한 번 등록한다. 등록 뒤의 붙이기·떼기는 관리자 권한 없이 Ubuntu에서 한다.

매번 하는 순서:

1. bitstream을 저장소 밖의 영구 폴더에 빌드한다: `bash 6_SoC/8bit_SoC/scripts/build_zybo.sh /home/sean/zybo_build`. WSL 배포판은 실행 중인 프로세스가 없으면 곧 멈추고, 다시 시작할 때 `/tmp`를 비운다(systemd `tmpfiles`의 `/tmp` 규칙). 그래서 bitstream은 `/tmp`에 두지 않는다.
2. 배선: USB-UART 변환기의 TX → FPGA RX(Pmod JC 2번, W15), RX → FPGA TX(JC 1번, V15), GND → JC 5번. 3.3 V 변환기만 쓴다.
3. 보드에 SD·QSPI 부팅 이미지가 있으면 PS가 PL을 다시 구성할 수 있으므로, 부팅 모드 점퍼(JP5)를 JTAG로 두기를 권장한다.
4. 보드의 PROG/UART micro-USB(J12)를 PC에 연결하고 전원을 켠 뒤 아래를 실행한다. [`scripts/program_zybo.sh`](../../../scripts/program_zybo.sh)가 Zybo를 WSL에 붙이고(이미 붙어 있으면 건너뜀) JTAG 장치 파일에 쓸 수 있는지 확인한다. 이어서 Linux Vivado를 batch로 실행한다([`scripts/program_zybo.tcl`](../../../scripts/program_zybo.tcl)). JTAG에서 xc7z020 장치 하나를 찾아(ARM DAP는 건너뜀) bitstream을 쓰고 DONE을 확인한다. 성공하면 `SOC8_ZYBO_PROGRAM_PASS`와 `RESULT status=0`이 나온다. 성공 조건(2026-11-12, Codex 검증 VR-014의 결함 I7 수정): Tcl은 DONE을 읽어 `1`일 때만 `SOC8_ZYBO_PROGRAM_PASS … done=1`을 출력하고, 읽기 실패나 다른 값이면 오류로 멈춘다. 셸은 Vivado 종료 코드 0, 로그의 `End of startup status: HIGH`, `SOC8_ZYBO_PROGRAM_PASS … done=1`이 모두 있어야 `status=0`이다. 보드 없이 이 규칙을 확인하는 시험은 [`scripts/selftest_program_zybo.sh`](../../../scripts/selftest_program_zybo.sh)다(tclsh와 가짜 Hardware Manager·가짜 vivado, 10사례). 다른 bitstream은 인자로 준다. `--detach`를 붙이면 끝난 뒤 보드를 host로 돌려준다. 붙어 있는 동안 보드는 host에서 보이지 않으며, WSL 가상 머신이 멈추면 떨어지므로 그때는 다시 실행한다.

   ```sh
   bash 6_SoC/8bit_SoC/scripts/program_zybo.sh
   ```

   GUI로 할 때는 Zybo를 붙인 뒤(`bash 6_SoC/8bit_SoC/scripts/wsl_usb.sh attach 0403:6010`) `/home/sean/Vivado/2024.2/bin/vivado &`(WSLg 창) → Open Hardware Manager → Open Target → Auto Connect → `xc7z020_1` → Program Device에서 `/home/sean/zybo_build/soc8_zybo_top.bit`를 고른다.
5. 확인: LD12(DONE)·LD0·LD1 켜짐, LD2·LD3 꺼짐. 계산기는 변환기를 WSL에 붙인 뒤 [PC 시험 도구](../../../pc_tools/README.md)(`calc_board_test.py`, 115200 bps 8E1)로 판정한다. BTN0을 누르면 reset된다.

기록:

- 2026-11-05 첫 프로그래밍은 host의 Windows Vivado Hardware Manager batch로 했다(당시 스크립트 `program_zybo.ps1`, 2026-11-09 Ubuntu 전용으로 바꾸며 삭제). JTAG 대상 1개, xc7z020 장치 1개(`xc7z020_1`, JTAG index 1), "End of startup status: HIGH", `SOC8_ZYBO_PROGRAM_PASS … done=1`, 약 35초. LED는 LD0·LD1 켜짐, LD2·LD3 꺼짐(사용자 관찰).
- 2026-11-09 Ubuntu 경로(`program_zybo.sh`, WSL Vivado 2024.2, sudo·규칙 설치 없이): Zybo attach(BUSID `1-4`) → JTAG 장치 파일 `/dev/bus/usb/001/004` 쓰기 가능 → JTAG 대상 1개(`xilinx_tcf/Digilent/210351BE7CD8A`), `xc7z020_1`, "End of startup status: HIGH", `SOC8_ZYBO_PROGRAM_PASS … done=1`, `RESULT status=0`, 28초. `--detach`를 주지 않았으므로 끝난 뒤 보드는 WSL에 붙은 상태(Attached)로 남는다.

## 전원을 켤 때 자동으로 올라오게 하기 (QSPI 부팅, Ubuntu)

PL 구성은 SRAM에 들어가므로 전원이 끊기면 지워진다. JP6이 USB이면 USB 케이블을 빼는 것도 전원 차단이다. Zynq는 PL만 flash에서 직접 구성하지 못한다. 전원을 켜면 PS의 BootROM이 JP5로 정한 장치에서 FSBL(first stage boot loader)을 읽고, FSBL이 boot image 안의 bitstream으로 PL을 구성한다(Zybo Z7 참조 설명서 2절). SoC bitstream에는 PS7 블록이 없으므로 FSBL을 `NON_PS_INSTANTIATED_BITSTREAM`으로 컴파일해 PL→PS 레벨 시프터를 켜지 않게 한다(Xilinx CR 671028). 켜면 구동되지 않는 PL→PS 인터럽트 선에서 IRQ가 나고, FSBL이 대체 부팅을 위해 시스템을 리셋하며 PL 구성도 지워진다. FSBL은 PL을 구성한 뒤 boot image의 첫 PS 프로그램으로 실행을 넘긴다. 그래서 `BOOT.bin`(FSBL + SoC bitstream + PS 대기 프로그램)을 보드의 16 MiB QSPI flash(3.3 V)에 기록한다. 설명서는 Spansion S25FL128S로 적지만 이 보드에서는 u-boot가 Winbond W25Q128JV로 감지했다. 기록기가 칩을 자동으로 인식하므로 flash 항목은 S25FL128S 3.3 V 항목을 그대로 쓴다. SoC의 RTL과 bitstream은 바꾸지 않는다. FSBL을 만들 때만 PS 설정이 필요하다.

처음 한 번 하는 준비:

1. Digilent 보드 파일(Zybo Z7-20의 PS 프리셋: DDR3L `MT41K256M16 RE-125`, MIO, QSPI)을 저장소 밖에 둔다. 출처는 [Digilent/vivado-boards](https://github.com/Digilent/vivado-boards/tree/master/new/board_files/zybo-z7-20/A.0)(MIT)이며, `board.xml` 40,818바이트·`part0_pins.xml` 6,788바이트·`preset.xml` 44,338바이트다.

   ```sh
   d=/home/sean/xilinx_boards/board_files/zybo-z7-20/A.0; mkdir -p $d && for f in board.xml part0_pins.xml preset.xml; do curl -fsSL -o $d/$f https://raw.githubusercontent.com/Digilent/vivado-boards/master/new/board_files/zybo-z7-20/A.0/$f; done
   ```

2. 도구: Vivado 2024.2(`/home/sean/Vivado/2024.2`, XSA·`bootgen`·flash 기록)와 Vitis 2024.2(`/home/sean/Vitis/2024.2`, FSBL 빌드).

순서(저장소 루트 기준):

1. boot image를 만든다. [`scripts/build_zybo_boot.sh`](../../../scripts/build_zybo_boot.sh)가 세 단계를 실행한다. 결과는 `/home/sean/zybo_build/boot/BOOT.bin`이고 약 70초 걸린다.
   1. PS만 있는 플랫폼 XSA([`scripts/zybo_ps_platform.tcl`](../../../scripts/zybo_ps_platform.tcl): `processing_system7` + 보드 프리셋, PL 쪽 포트 없음)
   2. FSBL(`NON_PS_INSTANTIATED_BITSTREAM`)과 PS 대기 프로그램([`scripts/zybo_fsbl.tcl`](../../../scripts/zybo_fsbl.tcl), `xsct -nodisp`). PS 프로그램은 Vitis `hello_world` 예제로, PS UART(J12의 두 번째 채널, 115200 8N1)에 "Hello World"를 출력한 뒤 DDR에서 대기한다. PL의 SoC는 PS를 쓰지 않는다.
   3. `bootgen -arch zynq`

   ```sh
   bash 6_SoC/8bit_SoC/scripts/build_zybo_boot.sh
   ```

   - XSA 단계의 critical warning 4건(`PSU-1`~`PSU-4`)은 보드 프리셋의 DQS-클록 지연 값이 음수라는 경고다. Digilent 프리셋 값 그대로이다.
2. flash에 기록한다. 먼저 SW4로 전원을 끄고 JP5를 JTAG에 둔 뒤 J12를 연결하고 전원을 켠다. Vivado는 JTAG 부팅 모드에서만 flash 기록을 지원한다(QSPI 모드에서는 경고가 나오고 기록이 도중에 멈출 수 있다). [`scripts/flash_zybo_qspi.sh`](../../../scripts/flash_zybo_qspi.sh)가 보드를 WSL에 붙이고, [`scripts/flash_zybo_qspi.tcl`](../../../scripts/flash_zybo_qspi.tcl)로 erase·program·verify를 한다(flash 항목 `s25fl128s-3.3v-qspi-x4-single`, FSBL로 PS 초기화). 성공하면 `SOC8_ZYBO_QSPI_PASS`와 `RESULT status=0`이 나오며, 약 3.5분 걸린다. `FLASH_TIMEOUT`(기본 600초) 안에 끝나지 않으면 스크립트가 Vivado를 멈추고 실패로 끝낸다. 로그는 `/home/sean/zybo_build/boot/flash_<날짜>_<시각>.log`로 남는다.

   ```sh
   bash 6_SoC/8bit_SoC/scripts/flash_zybo_qspi.sh
   ```

3. SW4로 전원을 끄고 JP5를 QSPI(가운데 두 핀)로 옮긴 뒤 전원을 켠다. JP5는 전원을 켤 때만 읽힌다. 몇 초 안에 LD12(DONE)가 켜지고 LD0·LD1이 켜지면 성공이다.
4. 그 뒤로는 전원을 껐다 켜거나 USB를 다시 꽂아도 PL이 자동으로 구성된다. RTL을 바꾸면 bitstream을 다시 빌드하고 1·2를 다시 한다. 개발 중에는 JTAG 프로그래밍(`program_zybo.sh`, 약 30초)이 빠르다. JP5를 JTAG로 되돌리면 전원을 켤 때 flash를 쓰지 않는다.

기록:

- 2026-11-09: 보드 파일을 받았고(크기 일치), `build_zybo_boot.sh`가 PASS했다(XSA `digilentinc.com:zybo-z7-20:part0:1.2`, FSBL text 82,832·data 10,484·bss 76,080바이트, `BOOT.bin` 4,149,824바이트, 70초). 첫 flash 기록은 erase·program·verify가 PASS했다(212초).
  - 이때 스크립트가 후보 목록의 첫 x4-single 항목인 `s25fl128s-1.8v-qspi-x4-single`을 골랐다. verify는 모든 바이트가 같아 기록 내용에는 문제가 없었다.
  - 보드 flash가 3.3 V이므로 `s25fl128s-3.3v-qspi-x4-single`로 고정했다.
  - 고정한 항목으로 다시 기록하려던 두 번째 실행은 FSBL을 내려받기 전에 멈췄다. 보드가 QSPI 부팅 모드였고(JP5가 처음부터 QSPI), Vivado가 "The current boot mode is QSPI" 경고를 냈다. 약 9분 뒤 프로세스를 종료했고, erase 전이었으므로 첫 실행의 기록 내용은 그대로 남았다. 이 일로 JP5 = JTAG 조건, 시간 제한, 날짜별 로그를 스크립트에 넣었다.
  - JP5 = QSPI로 전원을 켜자 LD3만 켜지고 LD12(DONE)는 꺼져 있었다. JTAG로 읽은 상태: 부팅 모드 QSPI, PL 미구성, `REBOOT_STATUS` 0xF048200C(SLC_RST 표시, BootROM 오류 0x200C). linear 모드 읽기(x1·quad)로 읽은 flash 앞부분과 FSBL 영역은 `BOOT.bin`과 같았다. 디버그 출력을 켠 FSBL을 JTAG로 실행하자 PS UART에 "FPGA Done !" → "Handoff Address: 0x00000000" → "IRQ_HANDLER"가 찍혔다. PL 구성은 성공했으나 IRQ 예외 → 대체 부팅 리셋 → PL 구성 삭제 순서로 실패했다. 처음에는 PS 프로그램이 없어 주소 0으로 넘어간 탓으로 보고 PS 대기 프로그램을 넣었지만, 같은 IRQ가 다시 났다. FSBL을 IRQ 처리 함수에서 멈춰 보니 IRQ는 hand-off 직전 `FsblHandoff`가 `ps7_post_config`로 PL→PS 레벨 시프터를 켤 때 났다. FSBL을 `NON_PS_INSTANTIATED_BITSTREAM`으로 다시 빌드해 같은 flash 이미지로 JTAG에서 실행하자 "SUCCESSFUL_HANDOFF", "Hello World"가 찍혔고, PL은 구성된 상태로 남았다. PS 대기 프로그램은 hand-off 대상으로 그대로 둔다.
  - 고친 `BOOT.bin`(4,168,904바이트)을 JP5 = JTAG에서 기록했다(erase·program·verify PASS, 68초). JP5 = QSPI로 전원을 켜자 LD12·LD0·LD1이 켜졌다(사용자 관찰). JTAG로 읽은 상태: `FPGA is configured`, `REBOOT_STATUS` 0x00400000(전원 투입 표시만, 오류 코드 없음), `LVL_SHFTR_EN` 0x0000000A(PL→PS 꺼짐).

## 기존 Zybo UART 보드 래퍼 참조

원본은 [1_RTL 공용 라이브러리](../../../../../1_RTL/2_TINY_PROJECT/UART/zybo_uart_top.v)에 있다. 이 SoC는 원본을 직접 읽으며 같은 모듈의 사본이나 심볼릭 링크를 이곳에 두지 않는다.

SoC용 연결 회로·제약·통합 TB를 추가할 때만 이 폴더에 새 파일을 작성한다. 단위 실행은 sources.json, 프로젝트 생성은 scripts/create_vivado.tcl의 공용 모듈 경로를 사용한다.
