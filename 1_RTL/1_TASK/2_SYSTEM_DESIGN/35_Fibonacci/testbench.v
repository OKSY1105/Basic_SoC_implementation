`timescale 1ns / 1ps

module testbench;

    // 파라미터 및 내부 신호 선언
    parameter TOTAL_SAMPLES = 20;

    reg         tb_clk;
    reg         tb_rst;
    wire [31:0] w_fib_data;

    integer     log_fd;
    integer     idx;
    integer     k;
    reg  [31:0] golden_fib [0:TOTAL_SAMPLES-1];

    // DUT 인스턴스화
    fibonacci_generator u_fib_gen (
        .i_clk     (tb_clk),
        .i_rst     (tb_rst),
        .o_fib_out (w_fib_data)
    );

    // 100MHz 클럭 생성 (5ns 토글)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    // 기대값(Golden Model) 배열 초기화
    initial begin
        golden_fib[0] = 32'd1;
        golden_fib[1] = 32'd1;
        for (k = 2; k < TOTAL_SAMPLES; k = k + 1) begin
            golden_fib[k] = golden_fib[k-1] + golden_fib[k-2];
        end
    end

    // 메인 시퀀스 및 로깅/검증 루프
    initial begin
        $timeformat(-9, 0, "ns", 6);
        log_fd = $fopen("output.txt", "w");

        // 초기화 및 리셋 (10ns 유지)
        tb_rst = 1'b1;
        #10 tb_rst = 1'b0;

        // 20 클럭 사이클 동안 샘플링 및 검증 수행
        for (idx = 0; idx < TOTAL_SAMPLES; idx = idx + 1) begin
            @(posedge tb_clk);
            
            // 결과 파일 출력
            $fdisplay(log_fd, "Time=%3t , Fibonacci(%2d) = %5d", $time, idx, w_fib_data);
            
            // 데이터 일치 여부 비교
            if (w_fib_data !== golden_fib[idx]) begin
                $fdisplay(log_fd, "Error: Fibonacci(%0d) = %d, Expected: %d", idx, w_fib_data, golden_fib[idx]);
            end
        end

        // 파일 닫기 및 시뮬레이션 종료
        $fclose(log_fd);
        $finish;
    end

endmodule
