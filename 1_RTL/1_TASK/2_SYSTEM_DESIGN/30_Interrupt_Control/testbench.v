`timescale 1ns / 1ps

module testbench;
    parameter INT_COUNT = 8;

    reg clk;
    reg rst_n;
    reg [INT_COUNT-1:0] interrupt_requests;
    reg interrupt_ack;
    wire [INT_COUNT-1:0] interrupt_service;
    wire interrupt_active;
    integer file;  

    // 모듈 인스턴스화 (RTL 모듈 이름 및 포트명 일치)
    interrupt_ctrl #(
        .INT_COUNT(INT_COUNT)
    ) u_interrupt_ctrl (
        .i_clk              (clk),
        .i_rst_n            (rst_n),
        .i_interrupt_req    (interrupt_requests),
        .i_interrupt_ack    (interrupt_ack),
        .o_interrupt_service(interrupt_service),
        .o_interrupt_active (interrupt_active)
    );

    // 클럭 생성
    always #5 clk = ~clk;

    initial begin
        file = $fopen("output.txt", "w");
        clk = 0;
        rst_n = 0;
        interrupt_requests = 0;
        interrupt_ack = 0;

        // 리셋 해제
        #20 rst_n = 1;

        // 테스트 시나리오
        #10 interrupt_requests = 8'b00000001; // 낮은 우선순위 인터럽트
        #20 interrupt_requests = 8'b00000011; // 두 개의 인터럽트
        #20 interrupt_requests = 8'b10000011; // 높은 우선순위 인터럽트 추가
        #20 interrupt_ack = 1; // 첫 번째 인터럽트 처리 완료
        #10 interrupt_ack = 0;
        #20 interrupt_ack = 1; // 두 번째 인터럽트 처리 완료
        #10 interrupt_ack = 0;
        #20 interrupt_ack = 1; // 세 번째 인터럽트 처리 완료
        #10 interrupt_ack = 0;
        #10;
        
        $fflush(file); // 마지막 출력 버퍼 저장
        $fclose(file);  
        #50 $finish;
    end

    // 결과 모니터링
    always @(posedge clk) begin
        $fdisplay(file,"Requests=%b, Active=%b, Service=%b", 
                  interrupt_requests, interrupt_active, interrupt_service);
    end

endmodule
