`timescale 1ns / 1ps
module testbench;

// 테스트 대상 모듈의 입출력 신호 정의
reg clk;
reg signal;
wire edge_detected;
integer file;  

// 테스트 대상 모듈 인스턴스화
rising_edge_detector uut (
    .i_clk(clk),
    .i_signal(signal),
    .o_edge_detected(edge_detected)
);

// 클럭 생성
always #5 clk = ~clk;

// 테스트 시나리오
initial begin
    $timeformat(-9, 0, "ns", 6); // -9: ns, 0: decimal place, "ns": unit, 10:minimum field width
    file = $fopen("output.txt", "w");
    // 초기화
    clk = 0;
    signal = 0;
    
    // 테스트 케이스 1: 단일 상승 에지
    #10 signal = 1;
    #10 signal = 0;
    
    // 테스트 케이스 2: 연속된 1
    #20 signal = 1;
    #20 signal = 1;
    #10 signal = 0;
    
    // 테스트 케이스 3: 빠른 토글
    #11 signal = 1;
    #5  signal = 0;
    #5  signal = 1;
    #5  signal = 0;
    
    // 테스트 케이스 4: 긴 0 상태 후 상승
    #31 signal = 1;
    #20
    // 시뮬레이션 종료
    #10;
    $fclose(file);  
    $finish;
end

// 결과 모니터링
always @(posedge clk) begin
    $fdisplay(file,"Time=%6t, Signal=%b, Edge Detected=%b", $time, signal, edge_detected);
end

endmodule