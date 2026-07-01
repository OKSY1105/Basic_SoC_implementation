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
