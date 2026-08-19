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

    interrupt_ctrl #(
        .INT_COUNT(INT_COUNT)
    ) u_interrupt_ctrl (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_interrupt_req(interrupt_requests),
        .i_interrupt_ack(interrupt_ack),
        .o_interrupt_service(interrupt_service),
        .o_interrupt_active(interrupt_active)
    );

    // 10ns 주기 클럭
    always #5 clk = ~clk;

    initial begin
        file = $fopen("output.txt", "w");
        clk = 0;
        rst_n = 0;
        interrupt_requests = 0;
        interrupt_ack = 0;

        // 리셋 해제
        #20 rst_n = 1;

        // 신호 입력을 하강 엣지 타이밍(#15)으로 맞춰 1클럭 여유를 줌
        #15 interrupt_requests = 8'b00000001; 
        #20 interrupt_requests = 8'b00000011; 
        #20 interrupt_requests = 8'b10000011; 
        #20 interrupt_ack = 1; 
        #10 interrupt_ack = 0;
        #20 interrupt_ack = 1; 
        #10 interrupt_ack = 0;
        #20 interrupt_ack = 1; 
        #10 interrupt_ack = 0;
        #10;
        
        $fclose(file);  
        #50 $finish;
    end

    // 결과 모니터링
    always @(posedge clk) begin
        $fdisplay(file, "Requests=%b, Active=%b, Service=%b", 
                  interrupt_requests, interrupt_active, interrupt_service);
    end

endmodule
