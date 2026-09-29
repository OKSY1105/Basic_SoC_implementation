`timescale 1ns / 1ps

module testbench;

    // 파라미터 및 신호 선언
    parameter SEQ_LEN = 16;

    reg         tb_clk;
    reg         tb_rst;
    reg  [2:0]  tb_digit_in;
    reg  [11:0] tb_code_in;
    wire [15:0] w_formatted_code;
    wire        w_match;

    integer     log_fd;
    integer     step_idx;

    // 테스트 입력 시퀀스 저장 배열 (2, 7, 4, 2, 1, 7, 3, 4, 5, 4, 2, 1, 7, 4, 0, 5)
    reg [2:0] test_pattern [0:SEQ_LEN-1];

    // DUT 인스턴스화
    safe_code_checker u_checker (
        .i_clk      (tb_clk),
        .i_rst      (tb_rst),
        .i_digit_in (tb_digit_in),
        .i_code_in  (tb_code_in),
        .o_match    (w_match)
    );

    // 100MHz 클럭 생성 (5ns 토글)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    // 12비트 입력 코드를 4비트 단위 16비트 16진수 포맷으로 변환
    assign w_formatted_code = {1'b0, tb_code_in[11:9], 1'b0, tb_code_in[8:6], 1'b0, tb_code_in[5:3], 1'b0, tb_code_in[2:0]};

    // 테스트 시퀀스 패턴 초기화
    initial begin
        test_pattern[0]  = 3'b010; // 2
        test_pattern[1]  = 3'b111; // 7
        test_pattern[2]  = 3'b100; // 4
        test_pattern[3]  = 3'b010; // 2
        test_pattern[4]  = 3'b001; // 1
        test_pattern[5]  = 3'b111; // 7
        test_pattern[6]  = 3'b011; // 3
        test_pattern[7]  = 3'b100; // 4
        test_pattern[8]  = 3'b101; // 5
        test_pattern[9]  = 3'b100; // 4
        test_pattern[10] = 3'b010; // 2
        test_pattern[11] = 3'b001; // 1
        test_pattern[12] = 3'b111; // 7
        test_pattern[13] = 3'b100; // 4
        test_pattern[14] = 3'b000; // 0
        test_pattern[15] = 3'b101; // 5
    end

    // 메인 시뮬레이션 제어
    initial begin
        $timeformat(-9, 0, "ns", 6);
        log_fd = $fopen("output.txt", "w");

        // 초기 상태 설정
        tb_code_in  = 12'b100_010_001_111; // 4 2 1 7
        tb_rst      = 1'b1;
        tb_digit_in = 3'b000;

        // 리셋 20ns 유지 후 해제
        #20 tb_rst = 1'b0;

        // 10ns 간격으로 입력 패턴 순차 인가
        for (step_idx = 0; step_idx < SEQ_LEN; step_idx = step_idx + 1) begin
            #10 tb_digit_in = test_pattern[step_idx];
        end

        // 시뮬레이션 종료
        #20;
        $fclose(log_fd);
        $finish;
    end

    // 결과 파일 실시간 로깅
    always @(posedge tb_clk) begin
        $fdisplay(log_fd, "Time=%3t, code = %h, digit_in=%d, match=%b", $time, w_formatted_code, tb_digit_in, w_match);
    end

endmodule
