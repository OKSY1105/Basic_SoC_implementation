# FPGA 프로젝트와 보드 파일

`projects/`는 기존 Vivado 프로젝트, `boards/zybo/`와 `constraints/`는 기존 UART 보드 예제다. 최종 보드 제약으로 자동 채택하지 않는다. 새 프로젝트는 [공용 Tcl](../scripts/create_vivado.tcl)로 현행 원본을 직접 참조해 생성한다. generated 결과는 build에 저장한다.
