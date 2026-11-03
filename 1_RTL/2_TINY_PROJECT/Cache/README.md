# Cache — 8bit SoC 데이터 캐시

8bit SoC의 RAM 경로에 들어가는 데이터 캐시다. 느린 DRAM 경로(바이트 읽기 약 100클록, 쓰기 약 200클록)를 hit일 때 1클록으로 줄인다.

```text
CPU 데이터 포트 ─AHB─▶ AHB 디코더 ─HSEL─▶ cache ─────────▶ DRAM 제어기 ─▶ DRAM 동작 모델
                                          (AHB-Lite slave,   (64bit 줄)
                                           바이트)
```

RAM용 AHB 래퍼는 따로 두지 않고 캐시가 AHB-Lite slave 단자를 직접 가진다. UART 같은 MMIO는 AHB 디코더가 따로 보내므로 캐시를 거치지 않는다.

## 구조

| 항목 | 값 |
|---|---|
| 방식 | 직접 사상(direct-mapped), `INDEX_W`=3 → 8줄 |
| 줄 크기 | 8바이트 = DRAM 열 하나의 burst(BL8 × 8bit). 줄 채우기·되쓰기가 DRAM 접근 1회 |
| 용량 | 데이터 64바이트 + 줄마다 tag 5bit·valid·dirty |
| 주소 (RAM 로컬 11bit) | tag [10:6] / index [5:3] / byte [2:0] |
| 쓰기 정책 | write-back + write-allocate (dirty 줄만 되씀) |
| hit 지연 | 데이터 단계 첫 클록에 완료(대기 0). 연속 hit는 1개/클록 |
| miss 처리 | dirty면 되쓰기 → 줄 채우기 동안 `HREADYOUT`=0, 그 뒤 hit로 완료 |
| reset | active-low 비동기 `i_rstn`. valid/dirty만 지운다. 아직 되쓰지 않은 dirty 데이터는 사라진다 |

## 포트

| 쪽 | 신호 | 규칙 |
|---|---|---|
| AHB-Lite slave(바이트) | `i_hsel`, `i_haddr[15:0]`, `i_htrans`, `i_hwrite`, `i_hsize`, `i_hwdata[7:0]`, `i_hready` → `o_hreadyout`, `o_hresp`, `o_hrdata[7:0]` | `HSEL && HTRANS[1] && HREADY`일 때 주소 단계 수락. `HADDR[10:0]`이 RAM 로컬 주소(상위 bit는 디코더가 검사). 바이트 전송만 지원하고 `HSIZE`≠000은 2클록 ERROR·부작용 없음. IDLE은 대기 없는 OKAY. `HREADYOUT`·`HRESP`는 데이터 단계 레지스터 상태로만 결정 |
| 메모리(줄) | `o_mem_req`, `o_mem_write`, `o_mem_address[7:0]`, `o_mem_wdata[63:0]` ← `i_mem_ack`, `i_mem_rdata[63:0]` | 요청은 ack까지 유지하고 `req && ack`인 상승 에지에서 한 번 완료. 주소는 줄 번호 = 바이트 주소 [10:3] = {row, column}. 줄의 바이트 k = [8k+7:8k] |
| 측정 | `o_access_count`, `o_miss_count`, `o_writeback_count` (16bit) | hit 수 = 접근 − miss. 시뮬레이션·보드 ILA에서 hit 비율 측정 |

메모리 쪽 64bit 줄 포트는 현재 DRAM 제어기에 아직 없다. 제어기에 줄 단위 포트를 추가하는 작업은 [SoC RAM 문서](../../../6_SoC/8bit_SoC/02_design/ram.md)의 FPGA RAM 방향에 있다.

## 시험

`tb_cache.sv`는 자체 판정 TB다.

- AHB master(TB 내장): 동작 목록을 파이프라인으로 실행한다(현재 데이터 단계 중 다음 주소 단계). `HREADY`=0 동안 주소 단계를, 쓰기 데이터 단계 동안 `HWDATA`를 유지하고, 무작위 빈 클록을 넣는다.
- 같은 버스의 다른 slave: 그 slave의 데이터 단계가 `HREADY`를 낮춘 동안 캐시가 주소 단계를 받지 않는지 검사한다.
- 기준: 2KiB 바이트 메모리. 모든 읽기를 기준과 비교한다.
- 줄 메모리 모델: 요청마다 1~8클록 뒤 응답하고, 대기 중 요청이 바뀌면 실패로 처리한다.
- 그림자 모델: 같은 정책(직접 사상, write-back)을 따로 구현해 hit·miss·되쓰기를 예측한다. 예측 hit가 데이터 단계 첫 클록에 완료하지 않거나 카운터가 다르면 실패다.
- 내용 검사: valid 줄과 메모리를 합친 내용이 기준과 같고, clean 줄은 메모리와 같아야 한다.
- 응답 규칙: 공용 SVA 검사기 [ahb_lite_slave_checker.sv](../BUS/ahb_lite_slave_checker.sv)(IDLE OKAY, 2클록 ERROR, 대기 상한).
- 시나리오: 지정 시나리오(clean miss, hit, 쓰기 hit, dirty 교체, 연속 hit 8회, `HSIZE` 오류, 다른 slave 대기 뒤 전송), 충돌 위주 무작위 20,000회(다른 slave 전송·`HSIZE` 오류 포함), 작업 집합 5,000회, 순차 읽기 512회, 줄 요청 대기 중 reset과 이후 무작위 2,000회.

실행 (저장소 루트 기준, 빈 작업 폴더에서):

```sh
# Windows (Vivado 2024.2)
C:\Xilinx\Vivado\2024.2\bin\xvlog.bat --sv -d AHB_LITE_SVA <저장소>/1_RTL/2_TINY_PROJECT/BUS/ahb_lite_slave_checker.sv <저장소>/1_RTL/2_TINY_PROJECT/Cache/cache.v <저장소>/1_RTL/2_TINY_PROJECT/Cache/tb_cache.sv
C:\Xilinx\Vivado\2024.2\bin\xelab.bat tb_cache -s tb_cache
C:\Xilinx\Vivado\2024.2\bin\xsim.bat tb_cache -runall

# Linux/WSL
xvlog --sv -d AHB_LITE_SVA <저장소>/1_RTL/2_TINY_PROJECT/BUS/ahb_lite_slave_checker.sv <저장소>/1_RTL/2_TINY_PROJECT/Cache/cache.v <저장소>/1_RTL/2_TINY_PROJECT/Cache/tb_cache.sv
xelab tb_cache -s tb_cache
xsim tb_cache -runall
```

통과하면 `CACHE_PASS ...`, 실패하면 `FAIL ...` 줄이 나온다.

## 결과 — 2026-11-03, Windows Vivado 2024.2 XSim

| 구간 | 접근 | miss | 되쓰기 | hit 비율 |
|---|---|---|---|---|
| 작업 집합 48바이트(6줄) | 5,000 | 5 | 1 | 99% (5,044클록) |
| 순차 읽기 512바이트 | 512 | 64 | 6 | 87% (줄당 miss 1회) |
| 충돌 위주 무작위 (최악 조건) | 19,407 | 15,392 | 6,952 | 20% |

- `CACHE_PASS accesses=24934 hits=9471 misses=15463 writebacks=6960 hit_rate=37% avg_miss_cycles=10 max_miss_cycles=21 b2b_8hits_cycles=9 bad_size_errors=223 other_slave_ops=425` (지정 시나리오 + 위 세 구간 합계, AHB 판, SVA 검사기 포함)
- 모든 hit가 데이터 단계 첫 클록에 완료했다. 연속 hit 8개 = 9클록(첫 주소 단계 1 + 1개/클록). reset 시나리오도 통과했다.
- 위 지연은 시험용 줄 메모리(1~8클록) 기준이다. 실제 DRAM 제어기와 연결한 지연은 제어기 줄 포트를 만든 뒤 측정한다.

변이 시험(저장소에 반영하지 않은 임시 사본, 모두 PASS 없음):

| 변이 | 첫 FAIL |
|---|---|
| 데이터 단계 레지스터를 `HREADY`와 무관하게 갱신 | `FAIL read 8010 got=xx expected=85` |
| dirty 줄 되쓰기 생략 | `FAIL dirty line was not written back` |
| 쓰기 hit에서 dirty를 세우지 않음 | `FAIL dirty line was not written back` |
| hit 판정에서 valid 무시 | `FAIL read 8000 got=5a expected=18` |
| `HSIZE` 오류를 1클록 ERROR로 | `FAIL HSIZE!=byte ... two-cycle ERROR`, `FAIL SVA a_err_first` |
| 줄 채우기 주소의 tag·index 뒤바꿈 | `FAIL read 8010 got=a8 expected=85` |
| 쓰기 hit가 옆 바이트를 바꿈 | `FAIL read 8012 got=ef expected=ab` |

`w_accept`에서 `i_hready`를 빼는 변이는 등가다. 데이터 단계 레지스터가 이미 `if (i_hready)` 안에서만 갱신되기 때문이다.

## 이력

- 이전 `cache.v`는 사용자의 초기 초안(8bit 주소·32bit 데이터, 8줄×4바이트, miss 처리·되쓰기 미완성)이었다. 2026-11-03 초안의 직접 사상·8줄·dirty 설계를 유지해 완성했고, 줄 크기는 DRAM burst에 맞춰 8바이트로 바꿨다. 초안은 git 이력(main `fa9ecf6`)에 남아 있다.
- 2026-11-03: CPU 쪽 req/ack 포트를 AHB-Lite slave 단자로 바꿨다(RAM AHB 래퍼를 캐시에 합침, `feat/8bit-soc` ed9e025). TB도 AHB master 방식으로 다시 작성했다.
