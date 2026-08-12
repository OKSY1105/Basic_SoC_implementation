`timescale 1ns / 1ps
module testbench;

    // 파라미터 정의
    parameter N = 8;
    
    // 테스트 대상 모듈의 입출력 신호 정의
    reg clk;
    reg rst;
    reg [N-1:0] data_in;
    reg [$clog2(N):0] shift_length;
    reg dir;
    wire [N-1:0] data_out;
    integer file;  

    // 테스트 대상 모듈 인스턴스화
    shift_register #(
        .N(N)
    ) uut (
        .i_clk(clk),
        .i_rst(rst),
        .i_data_in(data_in),
        .i_shift_length(shift_length),
        .i_dir(dir),
        .o_data_out(data_out)
    );

    // 클럭 생성
    always #5 clk = ~clk;

    // 테스트 시나리오
    initial begin
        file = $fopen("output.txt", "w");
        // 초기화
        clk = 0;
        rst = 1;
        data_in = 8'b10101010;
        shift_length = 0;
        dir = 0;

        // 리셋 해제
        #10 rst = 0;

        // 테스트 케이스 1: 왼쪽으로 2비트 시프트
        #10 dir = 0; shift_length = 2;
        #10 $fdisplay(file,"Test Case 1: Left shift 2 bits - Input: %b, Output: %b", data_in, data_out);

        // 테스트 케이스 2: 오른쪽으로 3비트 시프트
        #10 dir = 1; shift_length = 3;
        #10 $fdisplay(file,"Test Case 2: Right shift 3 bits - Input: %b, Output: %b", data_in, data_out);

        // 테스트 케이스 3: 왼쪽으로 8비트 시프트 (전체 시프트)
        #10 dir = 0; shift_length = 8;
        #10 $fdisplay(file,"Test Case 3: Left shift 8 bits - Input: %b, Output: %b", data_in, data_out);

        // 테스트 케이스 4: 오른쪽으로 1비트 시프트
        #10 dir = 1; shift_length = 1;
        #10 $fdisplay(file,"Test Case 4: Right shift 1 bit - Input: %b, Output: %b", data_in, data_out);

        // 테스트 케이스 5: 0비트 시프트 (변화 없음)
        #10 dir = 0; shift_length = 0;
        #10 $fdisplay(file,"Test Case 5: No shift - Input: %b, Output: %b", data_in, data_out);

        // 시뮬레이션 종료
        #10
        $fclose(file);  
        $finish;
    end

endmodule
