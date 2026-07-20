`timescale 1ns / 1ps

module testbench;
    // 테스트벤치 내부 자극(Stimulus) 및 모니터링용 변수 선언
    reg  [1:0] sel;   
    integer file;  

    // 모듈의 입력 포트에 연결할 wire/reg (이름 통일)
    wire       i_mux2sel;
    wire [1:0] i_mux4sel;
    wire       i_demux1to2_sel;
    wire       i_input1to2_sel;

    // 모듈의 출력 포트에 연결할 wire (이름 통일)
    wire       o_mux2sel;
    wire [1:0] o_mux4sel;
    wire [1:0] o_demux1to2_sel;

    // 입력 신호 할당 (기존 로직 유지)
    assign i_mux2sel       = sel[0];
    assign i_mux4sel       = sel;
    assign i_demux1to2_sel = sel[0];
    assign i_input1to2_sel = 1'b1; // 기존 demux_1to2_in의 값 2'd1 대응

    // [수정 포인트] 제공해주신 .v 파일의 포트 인터페이스에 맞춰 인스턴스화
    mux_demux u_mux_demux (
        .i_mux2sel         ( i_mux2sel         ),
        .o_mux2sel         ( o_mux2sel         ),
        .i_mux4sel         ( i_mux4sel         ),
        .o_mux4sel         ( o_mux4sel         ),
        .i_demux1to2_sel   ( i_demux1to2_sel   ),
        .i_input1to2_sel   ( i_input1to2_sel   ), // .v 파일의 입력 포트 매핑
        .o_demux1to2_sel   ( o_demux1to2_sel   )
    );

    // 로그 출력 및 파일 쓰기 제어
    initial begin
        file = $fopen("output.txt", "w");
        forever begin
            @(sel);
            #1;
            // 출력 변수명을 .v 모듈의 o_ 변수명으로 매핑 수정
            $display("mux_2to1   : sel = %d, out = %d", i_mux2sel, o_mux2sel);
            $fdisplay(file,"mux_2to1   : sel = %d, out = %d", i_mux2sel, o_mux2sel);
            
            $display("mux_4to1   : sel = %d, out = %d ", i_mux4sel, o_mux4sel);
            $fdisplay(file,"mux_4to1   : sel = %d, out = %d ", i_mux4sel, o_mux4sel);
            
            $display("demux_1to2 : sel = %d, in = %d, out_0 = %d, out_1 = %d", i_demux1to2_sel, i_input1to2_sel, o_demux1to2_sel[0], o_demux1to2_sel[1]);
            $fdisplay(file,"demux_1to2 : sel = %d, in = %d, out_0 = %d out_1 = %d", i_demux1to2_sel, i_input1to2_sel, o_demux1to2_sel[0], o_demux1to2_sel[1]);
            
            $display("---------------------------------------------------");
            $fdisplay(file,"---------------------------------------------------");
        end
    end

    // 자극 인가 블록
    initial begin
        sel = 0;
        #5;
        sel = 1;
        #5;
        sel = 2;
        #5;
        sel = 3;
        #5;
        $fclose(file);
        $finish;
    end

endmodule