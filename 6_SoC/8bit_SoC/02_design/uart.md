# UART 현행 구현과 통합 과제

[uart_top.v](../../../1_RTL/2_TINY_PROJECT/UART/uart_top.v)와 baud generator·RX·TX·FIFO를 인계했다. [기존 TB](../../../1_RTL/2_TINY_PROJECT/UART/tb_uart.v)는 tb_uart_top이며 [Zybo 래퍼](../../../1_RTL/2_TINY_PROJECT/UART/zybo_uart_top.v)는 보드 예제다.

- TX 입력: i_thr_we, i_thr_wdata.
- RX 읽기: i_rhr_re, o_rhr_rdata.
- 상태: data ready, THR empty, transmitter empty, frame/parity/overrun, FIFO full.
- 파라미터: CLK_FREQ_HZ, BAUD_RATE, DATA_BIT, FIFO_DEPTH. 기존 기본값을 전체 SoC 확정값으로 간주하지 않는다.

CPU 쪽 연결은 APB 래퍼(M9) [soc8_uart_apb.v](../rtl/uart/soc8_uart_apb.v)가 맡는다(아래 M9 절). 읽기/쓰기 부작용은 성공한 전송의 ACCESS 클록에 한 번만 일어난다. 빈 RX 읽기와 가득 찬 TX 쓰기는 기다리지 않고 ERROR로 응답한다. status bit 배치와 초기값은 레지스터 표를 따른다. CPU는 인터럽트(IRQ)로 동작한다(history H046).

## 코어 변경 — 2026-11-03

- 프레임은 코어에 고정된 8E1(데이터 8bit, 짝수 parity, stop 1bit)이다. RX FIFO와 TX FIFO는 맨 앞 데이터가 조합으로 보이는 구조(`o_r_data = mem[r_ptr]`)다.
- FE·PE·OE는 reset 전까지 유지되는 sticky bit였다. 래퍼의 ERROR_CLEAR(W1C)를 위해 `uart_rx`·`uart_top`에 `i_lsr_clr[2:0]`([0] OE, [1] FE, [2] PE)를 추가했다. 1이면 그 bit를 지우고, 같은 클록에 새 오류가 생기면 새 오류가 우선한다.
- 0으로 묶으면 기존 동작과 같다. `tb_uart.v`·`zybo_uart_top.v`에는 `3'b000`을 연결했다. 변경 뒤 기존 TB 결과도 같다(`tb_error=0`, `tb_done=1`, `$stop` 795,235 ns).
- 2026-11-04 수신 수정(③ 통합 시험에서 발견): `uart_rx`는 stop bit를 끝(16배 표본 tick 15)에서 판정하고 그때서야 대기 상태로 돌아갔다. start bit의 하강 에지는 대기 상태에서만 보므로, 바이트가 간격 없이 이어지면 다음 start bit를 놓치고 다음 프레임의 중간 하강 에지를 start로 잘못 잡았다. 송신 측 클록이 1% 빠르면 115200 bps에서도 생겼다(PC 터미널은 한 줄을 연속으로 보낸다). 이제 세 표본이 모두 모인 stop bit 중간(tick 10)에서 판정·저장하고 대기 상태로 돌아간다. 송신 측이 약 2.5% 빨라도 다음 start bit를 잡는다(남는 시간 = 11 bit − 10.625 bit − tick 위상). 시험: [03_uart/test.md](../04_unit/03_uart/test.md) 2026-11-04 절, [통합 TB](../tb/soc/README.md).
- 알려진 사항: `fifo.v`는 메모리를 비동기 reset always 블록 안에서 쓴다. 그래서 Vivado가 FIFO 메모리를 LUTRAM이 아닌 레지스터로 구현하고 set/reset 우선순위 경고를 낸다. 기능 문제는 아니며 이번에는 수정하지 않았다.

## M9 UART APB 래퍼 — 2026-11-03

[soc8_uart_apb.v](../rtl/uart/soc8_uart_apb.v)는 `uart_top`을 감싼 APB3 slave다. AHB→APB3 브리지가 `PSEL`을 직접 연결하며, `PADDR` = `HADDR[11:0]`이다.

| HADDR | PADDR | 이름 | 접근 | 동작 |
|---|---|---|---|---|
| FF00 | F00 | RX_DATA | R | RX FIFO에서 1바이트 pop. 비어 있으면 ERROR |
| FF01 | F01 | TX_DATA | W | TX FIFO에 1바이트 push. 가득 차 있으면 ERROR |
| FF02 | F02 | STATUS | R | [0] RX_VALID, [1] TX_FULL, [2] TX_BUSY(FIFO 또는 송신 중), [3] OVERRUN, [4] FRAME_ERR, [5] PARITY_ERR, [6] TX_EMPTY(TX FIFO 빔). reset 값 0x40 |
| FF03 | F03 | ERROR_CLEAR | W | bit 3/4/5에 1을 쓰면 해당 flag를 지움(W1C). 나머지 bit 무시 |
| FF04 | F04 | IRQ_EN | R/W | [0] RX_VALID, [1] TX_EMPTY, [2] 오류(OVERRUN·FRAME_ERR·PARITY_ERR). reset 0 |

- `PREADY`는 항상 1이다(대기 없음). AHB 쪽에서 UART 접근 1건은 브리지 대기 2클록을 포함해 3클록이 걸린다.
- `PSLVERR`(→ AHB ERROR, 부작용 없음): 잘못된 방향(RX_DATA·STATUS 쓰기, TX_DATA·ERROR_CLEAR 읽기), 0xF00~0xF04 밖의 `PADDR`, 빈 RX 읽기, 가득 찬 TX 쓰기.
- `o_irq` = 레지스터에 담은 (RX_VALID & EN0) | (TX_EMPTY & EN1) | ((OVERRUN | FRAME_ERR | PARITY_ERR) & EN2).
  - level 방식이다. 원인을 처리할 때까지 유지된다: RX를 읽거나, TX를 채우거나 EN1을 끄거나, flag를 지운다.
  - 상태보다 1클록 늦게 따라간다.
- reset: FIFO·flag 비움, IRQ_EN=0, `o_irq`=0.
- 시험: [04_unit/03_uart/test.md](../04_unit/03_uart/test.md) M9 절.

보드 연결과 설정(2026-11-04 결정): UART 인스턴스는 1개다. PC TX → FPGA RXD이고, FPGA TXD 한 선을 STM32 RX와 PC RX에 함께 연결한다. 115200 bps, 8E1, 3.3 V 레벨, 공통 GND다. 설계 클록 100 MHz에서 16배 오버샘플 분주는 54(실제 115,741 bps, +0.47%)다. Zybo Z7-20의 보드 USB-UART는 PS 쪽이므로 PC는 PL 핀의 외부 USB-UART 변환기로 연결하며, 핀은 FPGA 단계에서 정한다. 요청·응답 형식과 오류 응답은 [계산기 통신 규약](calculator.md)에 있다.
