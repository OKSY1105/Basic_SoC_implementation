`timescale 1ns / 1ps

module testbench;

reg       clk;
reg       areset;
reg       in;
wire      out_fsm;
integer   file;  

// 수정된 FSM 모듈 포트명에 맞춰 매핑
fsm u_fsm (
    .i_clk    ( clk     ),
    .i_areset ( areset  ),
    .i_in     ( in      ),   
    .o_fsm    ( out_fsm )
);

// 클록 생성
initial begin
    clk = 0;
    forever clk = #5 ~clk;
end

// 비동기 리셋 제어
initial begin
    areset = 1;
    #6;
    areset = 0;
end

// 테스트 시나리오
initial begin
    file = $fopen("output.txt", "w");
    
    // 초기화
    in = 0;
    #20;        
    #10 in = 1; 
    #10 in = 0;
    #20;        
    #10 in = 1; 
    #10 in = 0;
    #30;        
    #10 in = 1;
    #10 in = 0;
    #20;        
    #10 areset = 1; 
    #10 areset = 0;
    
    // 시뮬레이션 종료
    #10; 
    $fclose(file);
    $finish;
end 

// 모니터링 및 파일 출력
initial begin
    forever begin
        @(posedge clk);
        $display("areset=%b | in=%d | out_fsm=%b   ", areset, in, out_fsm);
        $fdisplay(file, "areset=%b | in=%d | out_fsm=%b   ", areset, in, out_fsm);
    end
end

endmodule