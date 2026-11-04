# SoC top — `soc8_top.v`

③ 통합 1단계(2026-11-04)에서 구현했다. 모듈 검증(VR-003~VR-010)을 통과한 모듈을 연결한다. 통합 TB는 [`tb/soc`](../../tb/soc/README.md)에 있고, [통합 기준](../../05_integration/README.md) I01~I03을 시뮬레이션에서 통과했다.

```text
CPU 명령 포트 ── ROM 포트 A (점대점, 16bit)
CPU 데이터 포트 ── soc8_ahb_bus ─┬ 0x0000-0x1FFF  ROM 포트 B (읽기 전용)
                                ├ 0x8000-0x87FF  캐시 ── DRAM 제어기 core ── DRAM 핀
                                ├ 0xF000-0xFFFF  AHB→APB3 브리지 ── UART (0xFF00-0xFF04)
                                └ 그 밖           기본 slave (ERROR)
UART o_irq ── CPU i_irq (level, 처리 루틴 벡터 워드 0x0002)
```

| 항목 | 내용 |
|---|---|
| 포함 모듈 | `reset_sync`(STAGES=2), `cpu8_top`, `soc8_rom`, `soc8_ahb_bus`, `cache`, `dram_controller_core`, `ahb_apb_bridge`, `soc8_uart_apb` |
| 파라미터 | `ROM_FILE`(ROM 이미지, `$readmemh` 16bit 워드), `CLK_FREQ_HZ`(100 MHz), `BAUD_RATE`(115200), `DRAM_T_RCD`·`DRAM_CL`·`DRAM_CWL`(9·9·10) |
| 클록 | `i_clk` 하나. 보드에서는 보드 top의 MMCM이 125 MHz 입력으로 100 MHz를 만든다. PCLK = HCLK, DRAM CK = `i_clk` / 4 |
| reset | `i_rst_n`(비동기, active low; 보드에서는 버튼 AND MMCM locked) → `reset_sync` → 모든 모듈. CPU·DRAM 제어기는 동기식, 나머지는 비동기식으로 받는다. 동기화된 reset은 `o_rst_n`으로도 낸다 |
| UART | `i_uart_rxd`·`o_uart_txd`(8E1). 보드 연결은 [계산기 통신 규약](../../02_design/calculator.md) 1절 |
| DRAM 핀 | 제어기 core의 분리 DQ/DQS(출력·출력 enable·입력, 3상태 없음). 시뮬레이션은 [`sim/models/soc8_dram_model.v`](../../sim/models/soc8_dram_model.v)(3상태 + 동작 모델 `dram.v`), 보드는 BRAM 기반 합성 가능 모델(M4)을 붙인다. 캐시는 64bit 줄 요청만 쓰며 줄 번호 = RAM 바이트 주소 `[10:3]`이다 |
| 디버그 출력 | CPU halt·fault·fault 코드·PC, IRQ·처리 루틴 실행 중, DRAM 초기화 완료, 캐시 접근·miss·write-back 수, 기본 slave 오류 주소·횟수(보드에서 ILA로 본다) |

## 합성 (out-of-context)

```sh
vivado -mode batch -nojournal -source scripts/synth_soc8_top.tcl   # 8bit_SoC 폴더 기준, WSL Vivado 2024.2
```

- 결과 (2026-11-04, `xc7z020clg400-1`, 10 ns 클록): `SOC8_SYNTH_PASS part=xc7z020clg400-1 lut=988 ff=1025 bram=2 lutram=69 latch=0 loops=0 wns_100mhz=0.459`
- 스크립트는 latch 0과 조합 루프 0(DRC LUTLP-1)을 확인한다. `SOC8_ROM_FILE`이 없으면 채운 의사 난수 ROM 이미지를 만들어 쓴다. 빈 ROM이면 합성이 CPU 대부분을 상수 논리로 지우기 때문이다.
- 같은 합성 결과를 한 번 배치·배선(opt·place·route, out-of-context, 핀 제약 없음)했을 때 WNS +0.991 ns, TNS 0, WHS +0.077 ns였다. 이 실행은 스크립트에 넣지 않은 1회 측정이다.
- 가장 느린 경로: 캐시 hit 판정(태그 비교) → 버스 `HREADY` → CPU 발행·분기 판단 → 명령 인출 주소 → ROM BRAM 읽기 enable(합성 기준 논리 8단). 데이터 포트 `HREADY`가 같은 클록 안에서 명령 인출 주소를 정하는 구조 때문이다. 보드 단계에서 타이밍이 부족하면 이 경로(예: 캐시 hit 판정을 주소 단계에서 미리 레지스터에 담기)를 먼저 본다.

## 연결 확인 (2026-11-04)

- `soc8_top`과 `soc8_dram_model`의 xvlog·xelab elaboration은 경고 없이 통과했다.
- 저장소 밖 임시 smoke 시험: ROM 프로그램이 RAM 0x8000·0x8040(같은 캐시 index)에 쓰고 0x8000을 다시 읽은 뒤 UART TX_DATA로 보내고 HALT했다. fault 없음, 읽은 값 0x5A, 캐시 접근 3·miss 3·write-back 2, 버스 오류 0, DRAM 모델에 두 줄이 write-back되었고, UART TX 줄에서 0x5A(parity·stop 정상)를 받았다.
- 판정을 갖춘 통합 TB는 [`tb/soc`](../../tb/soc/README.md)에 있다(③ 통합 2·3단계, I01~I03 시뮬레이션 PASS).
