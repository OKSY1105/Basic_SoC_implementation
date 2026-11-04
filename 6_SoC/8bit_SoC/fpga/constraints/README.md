# SoC 보드 제약

## SoC 보드 XDC — `soc8_zybo_z7_20.xdc` (2026-11-04)

Digilent Zybo Z7-20(`xc7z020clg400-1`)용 보드 top의 핀·클록 제약이다. 핀 번호와 I/O 표준은 Digilent `Zybo-Z7-Master.xdc`와 같고, UART 핀은 기존 UART_LED 예제와 같은 Pmod JC 핀이다. 보드 top(MMCM·reset·DRAM 모델 연결)은 Vivado에서 구성하며, 그 top의 포트 이름을 아래 표와 같게 한다.

| 포트 | 핀 | 내용 |
|---|---|---|
| `i_clk125` | K17 | 125 MHz PL 클록. `create_clock` 8 ns. MMCM이 만드는 100 MHz는 Vivado가 유도한다 |
| `i_btn_rst` | K18 (BTN0) | 누르는 동안 1. reset |
| `o_uart_txd` | V15 (Pmod JC, `jc_p[1]`) | FPGA 송신 → USB-UART 수신(PC)과 STM32 USART 수신 |
| `i_uart_rxd` | W15 (Pmod JC, `jc_n[1]`) | USB-UART 송신(PC) → FPGA 수신 |
| `o_led[3:0]` | M14, M15, G14, D18 (LD0~LD3) | 권장: [0] reset 해제(`o_rst_n`), [1] DRAM 초기화 완료, [2] CPU halt, [3] CPU fault |

- 모든 핀은 LVCMOS33이다. Zybo의 보드 USB-UART는 PS(MIO 48·49)에 연결되어 있으므로, PL UART에는 3.3 V USB-UART 변환기를 Pmod JC에 연결하고 GND를 공통으로 잇는다. 커넥터 핀 번호는 배선 전에 Zybo Z7 참조 설명서로 확인한다.
- 버튼과 UART 수신은 비동기 입력이다(버튼은 `reset_sync`, 수신선은 `uart_rx`의 2단 동기화기를 거친다). 송신선·LED는 외부 클록과 관계가 없다. 그래서 이 포트들에 `set_false_path`를 둔다.
- Clocking Wizard IP를 쓰면 IP도 입력 클록을 정의하므로, Vivado가 이 XDC의 정의가 IP의 정의를 대체한다고 알린다(주기는 같은 8 ns).

### 보드 top 연결 (Vivado에서 구성)

| 연결 | 내용 |
|---|---|
| 클록 | `i_clk125` → MMCM(125 → 100 MHz) → `soc8_top.i_clk`와 `dram_bram_model.i_clk`(같은 클록) |
| reset | `soc8_top.i_rst_n` = `!i_btn_rst && locked` |
| DRAM 핀 | `soc8_top`의 `o_dram_ck_t`·`o_dram_ck_c`·`o_dram_cke`·`o_dram_csn`·`o_dram_actn`·`o_dram_bg`·`o_dram_ba`·`o_dram_a`·`o_dram_dq`·`o_dram_dqs_t`·`o_dram_dqs_c` → [`dram_bram_model`](../../../../1_RTL/2_TINY_PROJECT/DRAM/dram_bram_model.v)의 같은 이름 입력(`i_ck_t` …). 모델 `o_dq` → `soc8_top.i_dram_dq`. `o_dram_dq_oe`·`o_dram_dqs_oe`·모델 `o_dq_oe`는 연결하지 않는다(3상태 없음) |
| UART | `i_uart_rxd` → `soc8_top.i_uart_rxd`, `soc8_top.o_uart_txd` → `o_uart_txd` |
| ROM | `soc8_top`의 `ROM_FILE` = 계산기 펌웨어 이미지(`calc.mem`, [펌웨어 README](../../firmware/README.md)의 빌드 명령으로 만든다). `CLK_FREQ_HZ`·`BAUD_RATE`는 기본값(100 MHz, 115200) |

## 기존 Zybo UART 제약 참조

원본은 [1_RTL 공용 라이브러리](../../../../1_RTL/2_TINY_PROJECT/FUNCTION_TEST/UART_LED/UART_LED.srcs/constrs_1/new/zybo_uart_top.xdc)에 있다. 이 SoC는 원본을 직접 읽으며 같은 모듈의 사본이나 심볼릭 링크를 이곳에 두지 않는다.

SoC용 연결 회로·제약·통합 TB를 추가할 때만 이 폴더에 새 파일을 작성한다. 단위 실행은 sources.json, 프로젝트 생성은 scripts/create_vivado.tcl의 공용 모듈 경로를 사용한다.
