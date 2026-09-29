`timescale 1ns / 1ps

module testbench;

    // 테스트 벤치 신호 선언
    reg     tb_clk;
    reg     tb_sig_in;
    wire    w_edge_flag;
    integer log_file;

    // DUT 인스턴스화
    rising_edge_detector u_edge_det (
        .i_clk           (tb_clk),
        .i_signal        (tb_sig_in),
        .o_edge_detected (w_edge_flag)
    );

    // 100MHz 클럭 생성 (5ns 토글)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    // 신호 제어 Task (시간 딜레이 후 신호 레벨 변경)
    task apply_stimulus;
        input integer delay_ns;
        input         level;
        begin
            #(delay_ns) tb_sig_in = level;
        end
    endtask

    // 테스트 시퀀스 실행
    initial begin
        $timeformat(-9, 0, "ns", 6);
        log_file = $fopen("output.txt", "w");

        // 초기 상태 설정
        tb_sig_in = 1'b0;

        // 테스트 케이스 1: 단일 상승 에지 (10ns -> 1, 10ns -> 0)
        apply_stimulus(10, 1'b1);
        apply_stimulus(10, 1'b0);

        // 테스트 케이스 2: 연속된 1 (20ns -> 1, 20ns -> 1, 10ns -> 0)
        apply_stimulus(20, 1'b1);
        apply_stimulus(20, 1'b1);
        apply_stimulus(10, 1'b0);

        // 테스트 케이스 3: 빠른 토글 (11ns, 5ns, 5ns, 5ns)
        apply_stimulus(11, 1'b1);
        apply_stimulus(5,  1'b0);
        apply_stimulus(5,  1'b1);
        apply_stimulus(5,  1'b0);

        // 테스트 케이스 4: 긴 0 상태 후 상승 (31ns -> 1)
        apply_stimulus(31, 1'b1);
        
        // 잔여 사이클 대기 및 종료
        #30;
        $fclose(log_file);
        $finish;
    end

    // 상승 에지 기준 결과 로깅 (원본 출력 포맷 100% 일치)
    always @(posedge tb_clk) begin
        $fdisplay(log_file, "Time=%6t, Signal=%b, Edge Detected=%b", $time, tb_sig_in, w_edge_flag);
    end

endmodule
