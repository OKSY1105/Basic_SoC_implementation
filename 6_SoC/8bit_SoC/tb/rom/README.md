# ROM TB

[단위 검증](../../04_unit/05_rom/test.md)을 따른다.

| 파일 | 대상 | 기대 출력 |
|---|---|---|
| `tb_soc8_rom.sv` | [soc8_rom.v](../../rtl/rom/soc8_rom.v) (M5) | `ROM_PASS` |
| `rom_test.mem` | 시험 이미지: 워드 0x000~0x00F, 0x7F8~0x807, 0xFF0~0xFFF (나머지 0). 실행 폴더에 복사해 둔다 | — |
