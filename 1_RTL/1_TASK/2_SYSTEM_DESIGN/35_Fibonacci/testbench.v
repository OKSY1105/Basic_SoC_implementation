`timescale 1ns / 1ps
module testbench;

    // 테스트 신호 정의
    reg clk;
    reg rst;
    wire [31:0] fib_out;
    integer file;  

    // 테스트할 모듈 인스턴스화
    fibonacci_generator uut (
        .i_clk(clk),
        .i_rst(rst),
        .o_fib_out(fib_out)
    );

    // 클럭 생성
    always begin
        #5 clk = ~clk;  // 10ns 주기의 클럭 생성
    end

    // 테스트 시나리오
    initial begin
        $timeformat(-9, 0, "ns", 6); // -9: ns, 0: decimal place, "ns": unit, 10:minimum field width
        file = $fopen("output.txt", "w");
        // 초기화
        clk = 0;
        rst = 1;
        
        // 리셋 해제
        #10 rst = 0;
        
        // 20개의 Fibonacci 수를 생성
        #200;
        
        // 테스트 종료
        $fclose(file);  
        $finish;
    end

    // 결과 모니터링
    integer cycle_count;
    initial begin
        cycle_count = 0;
        forever begin
            @(posedge clk);
            if (!rst) begin
                $fdisplay(file,"Time=%3t , Fibonacci(%2d) = %5d", $time, cycle_count, fib_out);
                cycle_count <= cycle_count + 1;
            end
        end
    end

    // 정확성 검증
    reg [31:0] expected_fib [0:19];
    integer j;
    initial begin
        expected_fib[0] = 1;
        expected_fib[1] = 1;
        for (j = 2; j < 20; j = j + 1) begin
            expected_fib[j] = expected_fib[j-1] + expected_fib[j-2];
        end
    end

    always @(posedge clk) begin
        if (!rst && cycle_count < 20) begin
            if (fib_out !== expected_fib[cycle_count]) begin
                $fdisplay(file,"Error: Fibonacci(%0d) = %d, Expected: %d", cycle_count, fib_out, expected_fib[cycle_count]);
            end
        end
    end

endmodule