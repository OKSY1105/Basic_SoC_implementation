# 검증 상태 (2026-10-22)

## 완료한 검사
1. CPU RTL 11개 파일에 중복된 모듈 선언이 없는지 확인.
2. 모든 하위 모듈의 인스턴스 및 named-port 연결의 누락/오타가 없는지 정적 점검.
3. 테스트벤치에서 작성한 34개 명령어를 ISA 규격에 따라 해석하는 별도 Python 행동 모델로 검사:
   - 최종 PC = `8'h42`
   - R0..R7 = `{0, 63, 19, 30, 20, 1, 128, 30}`
   - 외부 공용 byte array 주소 `8'h80`에 `8'd30` 기록
4. Testbench에 2-cycle stall, R/I/J, BEQ taken/not-taken, LW/SW, signed immediate, J 실행 시나리오 포함.

## 미실행 검사
- 이 컨테이너 환경에 `iverilog`/`verilator`가 설치되지 않아 **실제 RTL 컴파일과 Verilog 시뮬레이션은 수행하지 못함**.
- 따라서 Testbench의 최종 `PASS` 출력 및 파형은 아직 직접 확인하지 못함.

## 사용자 환경에서 수행
프로젝트 루트에서 `./run_sim.sh` 실행 (Icarus Verilog 필요).
또는 README의 `iverilog -g2012 ...` 명령으로 실행.
설계/검증 후 필요 시 지원받아 타이밍, 합성, waveform을 후속 점검할 수 있음.
