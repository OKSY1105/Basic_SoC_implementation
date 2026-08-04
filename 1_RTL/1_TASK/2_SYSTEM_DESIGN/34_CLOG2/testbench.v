`timescale 1ns / 1ps
module testbench;
 
    // 파라미터
    parameter DEPTH = 256;

    // clog2 함수 정의
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value - 1; i > 0; i = i >> 1) begin
                clog2 = clog2 + 1;
            end
        end
    endfunction

    // 테스트벤치 신호
    reg clk;
    reg rst;
    reg we;
    reg [clog2(DEPTH)-1:0] addr;
    reg [7:0] din;
    wire [7:0] dout;
    integer file;  

    // 테스트 결과 확인을 위한 변수
    integer errors;

    // DUT 인스턴스화 (수정된 포트명에 맞게 매핑)
    clog2 #(
        .DEPTH(DEPTH)
    ) dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_we(we),
        .i_addr(addr),
        .i_din(din),
        .o_dout(dout)
    );

    // 클록 생성
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 체커 태스크
    task check_data;
        input [clog2(DEPTH)-1:0] check_addr;
        input [7:0] expected;
        begin
            @(posedge clk);
            addr <= check_addr;
            we <= 0;
            @(posedge clk);
            #1;
            if (dout !== expected) begin
                $fdisplay(file,"Error: Address %0d, Expected %0h, Got %0h", check_addr, expected, dout);
                errors = errors + 1;
            end else begin
                $fdisplay(file,"Success: Address %0d, Data %0h", check_addr, dout);
            end
        end
    endtask

    // 테스트 시퀀스
    initial begin
        file = $fopen("output.txt", "w");
        // 초기화
        errors = 0;
        rst = 1;
        we = 0;
        addr = 0;
        din = 0;

        // 리셋 및 리셋 후 상태 확인
        #10 rst = 0;
        check_data(0, 8'h00);
        check_data(DEPTH-1, 8'h00);

        // 쓰기 테스트
        @(posedge clk) we <= 1; addr <= 5; din <= 8'hA5;
        @(posedge clk) we <= 1; addr <= 10; din <= 8'h5A;
        @(posedge clk) we <= 0;

        // 읽기 테스트
        check_data(5, 8'hA5);
        check_data(10, 8'h5A);

        // 존재하지 않는 데이터 체크 (초기값 0 예상)
        check_data(15, 8'h00);

        // 주소 범위 확인
        $fdisplay(file,"Address width: %0d bits", clog2(DEPTH));

        // 테스트 결과 보고
        if (errors == 0)
            $fdisplay(file,"All tests passed successfully!");
        else
            $fdisplay(file,"Tests completed with %0d errors.", errors);

        // 종료
        #10 
        $fclose(file);  
        $finish;
    end

endmodule