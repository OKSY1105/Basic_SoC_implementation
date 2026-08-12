`timescale 1ns / 1ps
module testbench;
    // 파라미터 정의
    parameter N = 4;  // 카운터의 개수
    parameter M = 8;  // 각 카운터의 비트 수

    // 테스트 대상 모듈의 입출력 신호 정의
    reg clk;
    reg rst;
    reg [N-1:0] enable;
    wire [M-1:0] count [N-1:0];
    integer file;  

    // 테스트 대상 모듈 인스턴스화
    parallel_counters #(
        .N(N),
        .M(M)
    ) uut (
        .i_clk(clk),
        .i_rst(rst),
        .i_enable(enable),
        .o_count(count)
    );

    // 클럭 생성
    always #5 clk = ~clk;

    // 테스트 시나리오
    initial begin
        $timeformat(-9, 0, "ns", 6); // -9: ns, 0: decimal place, "ns": unit, 10:minimum field width
        file = $fopen("output.txt", "w");
        // 초기화
        clk = 0;
        rst = 1;
        enable = 4'b0000;

        // 리셋 해제
        #10 rst = 0;

        // 각 카운터를 다른 시점에 활성화
        #20 enable[0] = 1;  // 20ns에 첫 번째 카운터 활성화
        #30 enable[1] = 1;  // 50ns에 두 번째 카운터 활성화
        #40 enable[2] = 1;  // 90ns에 세 번째 카운터 활성화
        #50 enable[3] = 1;  // 140ns에 네 번째 카운터 활성화

        // 100 클럭 사이클 동안 카운팅
        repeat(20) @(posedge clk);
        #5;
        // 각 카운터를 다른 시점에 비활성화
        #10 enable[1] = 0;  // 첫 번째로 두 번째 카운터 비활성화
        #20 enable[3] = 0;  // 그 다음 네 번째 카운터 비활성화
        #30 enable[0] = 0;  // 그 다음 첫 번째 카운터 비활성화
        #40 enable[2] = 0;  // 마지막으로 세 번째 카운터 비활성화

        // 추가로 5 클럭 사이클 동안 대기
        repeat(5) @(posedge clk);
        #5;
        // 시뮬레이션 종료
        $fclose(file);  
        $finish;
    end

    // 결과 모니터링
    always @(posedge clk) begin
        $fwrite(file,"Time=%4t, Enable=%b", $time, enable);
        for (int i = 0; i < N; i = i + 1) begin
            $fwrite(file," Counter[%0d]=%2d", i, count[i]);
        end
        $fwrite(file,"\n");
    end

endmodule
