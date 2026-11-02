# Cache — 8bit SoC 데이터 캐시

8bit SoC의 RAM 경로에 들어가는 데이터 캐시다. 느린 DRAM 경로(바이트 읽기 약 100클록, 쓰기 약 200클록)를 hit일 때 1클록으로 줄인다.

```text
CPU ─AHB─▶ RAM 래퍼 ─▶ cache ─▶ DRAM 제어기 ─▶ DRAM 동작 모델
                       (바이트)   (64bit 줄)
```

UART 같은 MMIO는 AHB 디코더가 따로 보내므로 캐시를 거치지 않는다.

## 구조

| 항목 | 값 |
|---|---|
| 방식 | 직접 사상(direct-mapped), `INDEX_W`=3 → 8줄 |
| 줄 크기 | 8바이트 = DRAM 열 하나의 burst(BL8 × 8bit). 줄 채우기·되쓰기가 DRAM 접근 1회 |
| 용량 | 데이터 64바이트 + 줄마다 tag 5bit·valid·dirty |
| 주소 (RAM 로컬 11bit) | tag [10:6] / index [5:3] / byte [2:0] |
| 쓰기 정책 | write-back + write-allocate (dirty 줄만 되씀) |
| hit 지연 | 요청을 낸 그 클록에 `o_cpu_ack` |
| miss 처리 | dirty면 되쓰기 → 줄 채우기 → 붙잡힌 요청이 hit로 완료 |
| reset | active-low 비동기 `i_rstn`. valid/dirty만 지운다. 아직 되쓰지 않은 dirty 데이터는 사라진다 |

## 포트

| 쪽 | 신호 | 규칙 |
|---|---|---|
| CPU(바이트) | `i_cpu_req`, `i_cpu_write`, `i_cpu_memaddr[10:0]`, `i_cpu_wdata[7:0]` → `o_cpu_ack`, `o_cpu_rdata[7:0]` | 요청은 ack까지 유지. `req && ack`인 상승 에지에서 한 번 완료 |
| 메모리(줄) | `o_mem_req`, `o_mem_write`, `o_mem_address[7:0]`, `o_mem_wdata[63:0]` ← `i_mem_ack`, `i_mem_rdata[63:0]` | 같은 req/ack 규칙. 주소는 줄 번호 = 바이트 주소 [10:3] = {row, column}. 줄의 바이트 k = [8k+7:8k] |
| 측정 | `o_access_count`, `o_miss_count`, `o_writeback_count` (16bit) | hit 수 = 접근 − miss. 시뮬레이션·보드 ILA에서 hit 비율 측정 |

CPU 쪽 규칙은 DRAM 제어기의 host 포트와 같다. 메모리 쪽 64bit 줄 포트는 현재 DRAM 제어기에 아직 없다. 제어기에 줄 단위 포트를 추가하는 작업은 [SoC RAM 문서](../../../6_SoC/8bit_SoC/02_design/ram.md)의 FPGA RAM 방향에 있다.

## 시험

`tb_cache.sv`는 자체 판정 TB다.

- 기준: 2KiB 바이트 메모리. 모든 읽기를 기준과 비교한다.
- 줄 메모리 모델: 요청마다 1~8클록 뒤 응답하고, 대기 중 요청이 바뀌면 실패로 처리한다.
- 그림자 모델: 같은 정책(직접 사상, write-back)을 따로 구현해 hit·miss·되쓰기를 예측한다. 예측 hit가 요청 클록에 응답하지 않거나 카운터가 다르면 실패다.
- 내용 검사: valid 줄과 메모리를 합친 내용이 기준과 같고, clean 줄은 메모리와 같아야 한다.
- 시나리오: 지정 시나리오(clean miss, hit, 쓰기 hit, dirty 교체, 연속 hit 8회), 충돌 위주 무작위 20,000회, 작업 집합 5,000회, 순차 읽기 512회, 줄 요청 대기 중 reset과 이후 무작위 2,000회.

실행 (저장소 루트 기준, 빈 작업 폴더에서):

```sh
# Windows (Vivado 2024.2)
C:\Xilinx\Vivado\2024.2\bin\xvlog.bat --sv <저장소>/1_RTL/2_TINY_PROJECT/Cache/cache.v <저장소>/1_RTL/2_TINY_PROJECT/Cache/tb_cache.sv
C:\Xilinx\Vivado\2024.2\bin\xelab.bat tb_cache -s tb_cache
C:\Xilinx\Vivado\2024.2\bin\xsim.bat tb_cache -runall

# Linux/WSL
xvlog --sv <저장소>/1_RTL/2_TINY_PROJECT/Cache/cache.v <저장소>/1_RTL/2_TINY_PROJECT/Cache/tb_cache.sv
xelab tb_cache -s tb_cache
xsim tb_cache -runall
```

통과하면 `CACHE_PASS ...`, 실패하면 `FAIL ...` 줄이 나온다.

## 결과 — 2026-11-03, Windows Vivado 2024.2 XSim

| 구간 | 접근 | miss | 되쓰기 | hit 비율 |
|---|---|---|---|---|
| 작업 집합 48바이트(6줄) | 5,000 | 6 | 1 | 99% |
| 순차 읽기 512바이트 | 512 | 64 | 7 | 87% (줄당 miss 1회) |
| 충돌 위주 무작위 (최악 조건) | 20,000 | 15,899 | 7,116 | 20% |

- `CACHE_PASS accesses=25525 hits=9554 misses=15971 writebacks=7125 hit_rate=37% avg_miss_cycles=10 max_miss_cycles=21` (지정 시나리오 + 위 세 구간 합계)
- 모든 hit가 요청 클록에 응답했다. reset 시나리오도 통과했다.
- 변이 시험: dirty 되쓰기를 끈 임시 사본에서 `FAIL dirty line was not written back` 등 실패가 검출됐다(저장소에는 반영하지 않음).
- 위 지연은 시험용 줄 메모리(1~8클록) 기준이다. 실제 DRAM 제어기와 연결한 지연은 제어기 줄 포트를 만든 뒤 측정한다.

## 이력

- 이전 `cache.v`는 사용자의 초기 초안(8bit 주소·32bit 데이터, 8줄×4바이트, miss 처리·되쓰기 미완성)이었다. 2026-11-03 초안의 직접 사상·8줄·dirty 설계를 유지해 완성했고, 줄 크기는 DRAM burst에 맞춰 8바이트로 바꿨다. 초안은 git 이력(main `fa9ecf6`)에 남아 있다.
