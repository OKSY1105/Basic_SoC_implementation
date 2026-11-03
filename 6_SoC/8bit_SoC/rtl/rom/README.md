# ROM 개발 위치

| 파일 | 내용 | 시험 |
|---|---|---|
| `soc8_rom.v` | 프로그램 ROM (M5): 4K×16bit 블록 ROM, AHB-Lite slave 포트 2개 | [tb_soc8_rom.sv](../../tb/rom/tb_soc8_rom.sv) |

| 항목 | 포트 A (명령) | 포트 B (데이터) |
|---|---|---|
| 연결 | CPU 명령 포트와 점대점 (`HSEL`=1, `HREADY`=자기 `HREADYOUT`) | CPU 데이터 포트 → [AHB 디코더](../bus/soc8_ahb_bus.v) (`HSEL` = 0x0000~0x1FFF) |
| 주소 | 17bit 바이트 주소 `{PC,1'b0}`, 워드 = `HADDR[12:1]` | 16bit 바이트 주소, 워드 = `HADDR[12:1]`, 바이트 = `HADDR[0]` |
| 데이터 | 16bit 명령 | 8bit. little endian: 짝수 주소 = 워드 [7:0], 홀수 주소 = [15:8] |
| 정상 전송 | 하프워드 읽기(`HSIZE`=001, 짝수 주소, 0x00000~0x01FFF), 대기 0 | 바이트 읽기(`HSIZE`=000), 대기 0 |
| ERROR (2클록, 부작용 없음) | 쓰기, `HSIZE`≠001, 홀수 주소, 0x02000 이상 — CPU는 인출 fault(코드 2)로 처리 | 쓰기, `HSIZE`≠000 |

- 읽기: 주소 단계가 수락되는 클록(`HSEL && HTRANS[1] && HREADY`)에 배열을 읽는다(enable이 있는 BRAM 읽기). 그래서 데이터 단계에 데이터가 준비되어 있고, 다음 읽기가 수락될 때까지 유지된다. 두 포트는 독립적으로 읽는다(2포트 읽기).
- 내용: 파라미터 `MEM_FILE`(`$readmemh`, 한 줄에 16bit 16진수 워드 1개, `@주소` 사용 가능). 파일에 없는 워드는 0이다. reset은 내용을 바꾸지 않는다.
- `HREADYOUT`·`HRESP`는 데이터 단계 레지스터 상태로만 결정하고, IDLE은 대기 없는 OKAY로 응답한다.
