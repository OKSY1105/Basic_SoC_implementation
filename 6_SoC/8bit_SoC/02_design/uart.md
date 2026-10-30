# UART 현행 구현과 통합 과제

[uart_top.v](../../../1_RTL/2_TINY_PROJECT/UART/uart_top.v)와 baud generator·RX·TX·FIFO를 인계했다. [기존 TB](../../../1_RTL/2_TINY_PROJECT/UART/tb_uart.v)는 tb_uart_top이며 [Zybo 래퍼](../../../1_RTL/2_TINY_PROJECT/UART/zybo_uart_top.v)는 보드 예제다.

- TX 입력: i_thr_we, i_thr_wdata.
- RX 읽기: i_rhr_re, o_rhr_rdata.
- 상태: data ready, THR empty, transmitter empty, frame/parity/overrun, FIFO full.
- 파라미터: CLK_FREQ_HZ, BAUD_RATE, DATA_BIT, FIFO_DEPTH. 기존 기본값을 전체 SoC 확정값으로 간주하지 않는다.

CPU req/ready와 UART의 FIFO pulse 포트는 직접 같은 신호가 아니다. BUS MMIO 어댑터가 읽기/쓰기 부작용을 완료당 한 번만 발생시키고 FIFO full/empty·wait/reset·오류 상태를 처리해야 한다. RX 준비 전 읽기를 기다릴지 오류로 응답할지, TX full에서의 정책, status bit 배치와 초기값은 아직 결정해야 한다.

PC→FPGA RX와 FPGA TX→STM32 RX의 물리 연결, 공통 GND·레벨·최종 baud를 확인한다. 추가 양방향 통신이나 UART 인스턴스 수는 핀/통신 요구를 보고 결정한다. 패킷 문법·체크섬·시간초과·오류 응답은 후속 명세다.
