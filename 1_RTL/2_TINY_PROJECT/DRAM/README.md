# DRAM Circuit Design

## DQS 스트로브별 curr_data 저장 위치

| 클럭 카운트 | 스트로브 | 조각 | curr_data 저장 위치 |
|:-----------:|:--------:|:----:|:-------------------:|
| cnt == tCWL   | dqs_c ↓ | 1번째 | [ 7: 0] |
| cnt == tCWL   | dqs_t ↑ | 2번째 | [15: 8] |
| cnt == tCWL+1 | dqs_c ↓ | 3번째 | [23:16] |
| cnt == tCWL+1 | dqs_t ↑ | 4번째 | [31:24] |
| cnt == tCWL+2 | dqs_c ↓ | 5번째 | [39:32] |
| cnt == tCWL+2 | dqs_t ↑ | 6번째 | [47:40] |
| cnt == tCWL+3 | dqs_c ↓ | 7번째 | [55:48] |
| cnt == tCWL+3 | dqs_t ↑ | 8번째 | [63:56] |

## 코드

```verilog
	always @(posedge dqs_c)
		if (cnt == tCWL) 	curr_data[ 7:0 ] <= dq_i;
		else if (cnt == tCWL+1) 	curr_data[23:16] <= dq_i;
		else if (cnt == tCWL+2) 	curr_data[39:32] <= dq_i;
		else if (cnt == tCWL+3) 	curr_data[55:48] <= dq_i;

	always @(posedge dqs_t)
		if (cnt == tCWL) 	curr_data[15:8 ] <= dq_i;
		else if (cnt == tCWL+1) 	curr_data[31:24] <= dq_i;
		else if (cnt == tCWL+2) 	curr_data[47:40] <= dq_i;
		else if (cnt == tCWL+3) 	curr_data[63:56] <= dq_i;
    ...
```

## 명령어별 동작 설명

### 1. ACT (Activate)

**물리적 동작:** 특정 Wordline에 고전압을 가해 해당 Row의 셀들이 품은 전하를 센스 앰프(Row Buffer)로 쏟아내게 만듭니다.

**코드 동작:**
- `row <= a[3:0]` : Row 주소 저장
- `write_op <= 0; read_op <= 0` : 이전 작업 플래그 초기화
- `cnt <= 0` : 카운터 리셋

> ACT는 단순히 문만 여는 게 아닙니다.
> 1. 뚜껑을 열어 데이터를 쏟아냄 (데이터 파괴)
> 2. 센스 앰프가 받아내서 0/1 판별
> 3. 원래 셀에 데이터 복원
> 4. Row Buffer에 값을 들고 CAS 신호 대기

---

### 2. WR (Write)

**물리적 동작:** 열려있는 Row 안에서 특정 Column 스위치를 열고, 외부 핀(`dq`)에서 데이터가 날아오길 기다립니다.

**코드 동작:**
- `col <= a[3:0]` : Col 주소 저장
- `write_op <= 1` : 데이터 수신 모드 ON
- `cnt <= 1` : 카운터 시작

---

### 3. `cnt == tCWL+4`일 때 왜 `write_op <= 0`인가?

`write_op`의 진짜 의미는 "메모리에 값을 써라"가 아니라 **"8조각 데이터를 64비트 금고(`curr_data`)로 긁어모으는 중"** 입니다.

`cnt == tCWL+4`가 되면 64비트 조립 완료 → `write_op <= 0`으로 수신 종료.

```verilog
always @(posedge ck_t)
    if (write_op && cnt == tCWL+4) data_write <= 1;
    else data_write <= 0;

always @(posedge ck_t)
    if (data_write) mem[row][col] <= curr_data;
```

| 단계 | 의미 |
|:----:|:-----|
| `write_op = 1` | 잠자리채 펼치고 대기 (수신 모드) |
| `cnt == tCWL+4` | 벌레 8마리 다 들어온 순간 |
| `write_op = 0` | 잠자리채 닫음 (수신 종료) |
| `data_write = 1` | 채집통(`mem`)에 털어 넣음 (실제 기록) |
## 코드
[dram.v](dram.v) 참고

## 보드용 모델 `dram_bram_model.v` (2026-11-04)

`dram.v`는 3상태 DQ와 DQS 에지 클록을 쓰는 시뮬레이션 전용 모델이라 FPGA에 올릴 수 없다. Zybo Z7-20의 DDR3는 PS 전용이어서 직접 만든 제어기가 구동할 수 없으므로, 보드에서는 [dram_bram_model.v](dram_bram_model.v)를 FPGA 안에 두고 `dram_controller_core`에 바로 연결한다.

| 항목 | `dram.v` | `dram_bram_model.v` |
|---|---|---|
| 클록 | CK 상승(`posedge ck_t`), DQS 상승 | 시스템 클록 `i_clk` 하나. CK·DQS 핀을 `i_clk`로 표본화해 상승을 검출한다(같은 에지를 1 `i_clk` 늦게 본다) |
| 저장 | `mem[row][col]` 레지스터 배열 | BRAM, `mem[{row, col}]` 256워드 × 64bit (2차원 배열은 Vivado가 BRAM으로 추론하지 않는다) |
| DQ | inout(3상태) | 입력 `i_dq`, 출력 `o_dq`·`o_dq_oe` |
| 읽기 DQS | `ck_t`·`ck_c`를 그대로 낸다 | 내지 않는다(제어기 core는 CK의 고정 위상에서 읽는다) |
| 명령·지연 | ACT/RD/WR/MRS, CL 9·10(MR0), CWL 10·11(MR2), 마지막 쓰기 바이트 뒤 CK 2에지에 배열 기록 | 같다 |
| 초기값 | X | 0(FPGA 구성 때) |
| 사용 조건 | — | CK = `i_clk` / 4(제어기 규칙: 2클록 high, 2클록 low) |

- 쓰기: DQS 상승을 검출한 `i_clk` 끝에서 DQ 바이트를 받는다. 바이트 위치는 위 표와 같다.
- 읽기: 카운트가 CL~CL+3인 동안 DQ를 낸다. CK high 첫 `i_clk`에서는 카운트가 그 클록 끝에 갱신되므로 `cnt + 1`을 쓴다. CK high 동안 짝수 바이트, low 동안 홀수 바이트를 내고, 제어기는 CK 에지 1/4주기 뒤에 읽는다.
- 시험: 제어기 TB 두 개를 `-d DRAM_BRAM_MODEL`로 이 모델에서 실행하고, `-d DRAM_MODEL_MATCH`로 `dram.v` 옆에서 매 클록 비교한다([DRAM 제어기 README](../DRAM_CONTEOLLER/README.md), 결과는 [SoC RAM 단위 검증](../../../6_SoC/8bit_SoC/04_unit/02_ram/test.md)).
