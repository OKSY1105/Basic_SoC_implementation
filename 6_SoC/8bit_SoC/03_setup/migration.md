# 경로 개편과 호환 링크

작업 시각: 2026-10-30T10:21:30+09:00

사용자 선택: 기존 Sercurity와 분리한 6_SoC/8bit_SoC. 이동 전에 기존 소스와 프로젝트 전체를 외부 before_move.tar.gz에 보관하고 SHA-256을 기록했다.

| 기존 저장소 상대 경로 | 현행 저장소 상대 경로 |
|---|---|
| `1_RTL/2_TINY_PROJECT/CPU/8bit_CPU` | `6_SoC/8bit_SoC/rtl/cpu/8bit_CPU` |
| `1_RTL/2_TINY_PROJECT/DRAM` | `6_SoC/8bit_SoC/sim/models/DRAM` |
| `1_RTL/2_TINY_PROJECT/FUNCTION_TEST/UART_LED` | `6_SoC/8bit_SoC/fpga/projects/uart_led` |
| `6_SoC/8bit_SoC/rtl/cpu/8bit_CPU/8bit_cpu_sim` | `6_SoC/8bit_SoC/fpga/projects/cpu/8bit_cpu_sim` |
| `6_SoC/8bit_SoC/fpga/projects/uart_led/UART_LED.srcs/constrs_1/new/zybo_uart_top.xdc` | `6_SoC/8bit_SoC/fpga/constraints/zybo_uart_top.xdc` |
| `1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/dram_controller.v` | `6_SoC/8bit_SoC/rtl/ram/dram_controller.v` |
| `1_RTL/2_TINY_PROJECT/DRAM_CONTEOLLER/tb_dram_controller.v` | `6_SoC/8bit_SoC/tb/ram/tb_dram_controller.v` |
| `1_RTL/2_TINY_PROJECT/UART/tb_uart.v` | `6_SoC/8bit_SoC/tb/uart/tb_uart.v` |
| `1_RTL/2_TINY_PROJECT/UART/zybo_uart_top.v` | `6_SoC/8bit_SoC/fpga/boards/zybo/zybo_uart_top.v` |
| `1_RTL/2_TINY_PROJECT/UART/baud_rate_gen.v` | `6_SoC/8bit_SoC/rtl/uart/baud_rate_gen.v` |
| `1_RTL/2_TINY_PROJECT/UART/fifo.v` | `6_SoC/8bit_SoC/rtl/uart/fifo.v` |
| `1_RTL/2_TINY_PROJECT/UART/uart_rx.v` | `6_SoC/8bit_SoC/rtl/uart/uart_rx.v` |
| `1_RTL/2_TINY_PROJECT/UART/uart_tx.v` | `6_SoC/8bit_SoC/rtl/uart/uart_tx.v` |
| `1_RTL/2_TINY_PROJECT/UART/uart_top.v` | `6_SoC/8bit_SoC/rtl/uart/uart_top.v` |

이전 위치는 파일 사본 대신 상대 심볼릭 링크로 현행 원본을 가리킨다. WSL/Linux Git의 symlink 지원이 필요하다. Windows에서 사용할 때는 WSL 경로로 연다. 기존 Tiny Project의 Vivado 로그/캐시와 UART legacy Tcl은 원래 위치에 보존했다.

기존 CPU imported 프로젝트는 당시 소스 사본을 포함한다. 직접 참조 방식의 새 프로젝트는 scripts/create_vivado.tcl로 생성한다. UART LED XPR의 입력 경로는 이동한 현행 소스/보드 래퍼/XDC로 다시 연결했다.

기능 RTL/TB 바이트는 그대로 유지했다. 경로 수정 대상은 UART LED 프로젝트 XML과 새 문서/도구다. 이동한 모든 파일의 해시와 보호 대상 Sercurity 지문을 확인한다.

공유 기록: C:/codex_project의 AGENTS/Resume/history는 기존 Vault 검사 오류로 안전 저장이 차단되어 변경하지 않았다. 기존 CPU 코드 경로는 호환 링크를 통해 유효하다. 새 실제 경로와 공유 기록 반영 사항은 외부 pending_vault_record.md에도 남긴다.

원본 백업·이동 지문·검증 로그는 C:/Users/okhou/.codex/visualizations/2026/10/23/01a16780-b1e1-7d30-9694-739a8f485015/soc_reorg_20261030에 있다.
