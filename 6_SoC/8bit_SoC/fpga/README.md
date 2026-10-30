# SoC FPGA 프로젝트와 제약

단독 CPU/UART 프로젝트와 보드 예제는 1_RTL의 각 모듈 폴더에 있다. 이 폴더에는 SoC 통합용 보드 설정/제약을 추가한다. 현재 하위 README는 해당 공용 원본으로 안내한다.

새 단위 프로젝트는 [공용 생성 Tcl](../scripts/create_vivado.tcl)로 만든다. RTL을 import/copy하지 않고 1_RTL 원본을 직접 참조한다. 생성 결과는 build에 저장하며 최종 보드/핀/클록을 자동 확정하지 않는다.
