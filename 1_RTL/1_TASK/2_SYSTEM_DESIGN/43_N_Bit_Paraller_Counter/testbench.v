`timescale 1ns / 1ps

module testbench;

    // 파라미터 정의
    parameter NUM_COUNTERS = 4;
    parameter COUNTER_BITS = 8;

    // 테스트 신호 선언
    reg                      tb_clk;
    reg                      tb_rst;
    reg  [NUM_COUNTERS-1:0]  tb_enable;
    wire [COUNTER_BITS-1:0]  w_count [NUM_COUNTERS-1:0];

    integer log_fd;
    integer loop_idx;

    // DUT 인스턴스화
    parallel_counters #(
        .N(NUM_COUNTERS),
        .M(COUNTER_BITS)
    ) u_parallel_cnt (
        .i_clk    (tb_clk),
        .i_rst    (tb_rst),
        .i_enable (tb_enable),
        .o_count  (w_count)
    );

    // 100MHz 클럭 생성 (5ns 토글)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    // 활성화/비활성화 비트 제어 Task
    task update_enable_bit;
        input integer delay_step;
        input integer bit_idx;
        input         bit_val;
        begin
            #(delay_step);
            tb_enable[bit_idx] = bit_val;
        end
    endtask

    // 메인 시뮬레이션 제어 시퀀스
    initial begin
        $timeformat(-9, 0, "ns", 6);
        log_fd = $fopen("output.txt", "w");

        // 초기화 및 리셋 (10ns 유지)
        tb_rst    = 1'b1;
        tb_enable = {NUM_COUNTERS{1'b0}};
        #10 tb_rst = 1'b0;

        // 순차적 카운터 활성화 시퀀스
        update_enable_bit(20, 0, 1'b1);  // 20ns 후 카운터 0 활성화
        update_enable_bit(30, 1, 1'b1);  // 50ns 후 카운터 1 활성화
        update_enable_bit(40, 2, 1'b1);  // 90ns 후 카운터 2 활성화
        update_enable_bit(50, 3, 1'b1);  // 140ns 후 카운터 3 활성화

        // 20 클럭 사이클 동안 카운팅 동작 수행
        repeat(20) @(posedge tb_clk);
        #5;

        // 순차적 카운터 비활성화 시퀀스
        update_enable_bit(10, 1, 1'b0);  // 카운터 1 비활성화
        update_enable_bit(20, 3, 1'b0);  // 카운터 3 비활성화
        update_enable_bit(30, 0, 1'b0);  // 카운터 0 비활성화
        update_enable_bit(40, 2, 1'b0);  // 카운터 2 비활성화

        // 추가 5 클럭 사이클 대기
        repeat(5) @(posedge tb_clk);
        #5;

        // 시뮬레이션 종료
        $fclose(log_fd);
        $finish;
    end

    // 결과 로깅 (원본 출력 포맷 100% 일치)
    always @(posedge tb_clk) begin
        $fwrite(log_fd, "Time=%4t, Enable=%b", $time, tb_enable);
        for (loop_idx = 0; loop_idx < NUM_COUNTERS; loop_idx = loop_idx + 1) begin
            $fwrite(log_fd, " Counter[%0d]=%2d", loop_idx, w_count[loop_idx]);
        end
        $fwrite(log_fd, "\n");
    end

endmodule
