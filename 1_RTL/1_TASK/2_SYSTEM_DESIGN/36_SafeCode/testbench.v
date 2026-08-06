`timescale 1ns / 1ps
module testbench;
   // 테스트할 모듈의 입출력 신호
    reg clk;
    reg rst;
    reg [2:0] digit_in;
    reg [11:0] code_in;
    wire [15:0] code;
    wire match;
    integer file;  

    // 테스트할 모듈 인스턴스화
    safe_code_checker uut (
        .i_clk(clk),
        .i_rst(rst),
        .i_digit_in(digit_in),
        .i_code_in(code_in),
        .o_match(match)
    );

    // 클럭 생성
    always begin
        #5 clk = ~clk;  // 10ns 주기의 클럭
    end

    // 테스트 시나리오
    initial begin
        $timeformat(-9, 0, "ns", 6); // -9: ns, 0: decimal place, "ns": unit, 10:minimum field width
        file = $fopen("output.txt", "w");
        code_in = 12'b100_010_001_111;  // 4 2 1 7
        clk = 0;
        rst = 1;
        digit_in = 3'b000;

        // 리셋 해제
        #20 rst = 0;


        // 입력 시퀀스: 2742173454217485
        #10 digit_in = 3'b010;  // 2
        #10 digit_in = 3'b111;  // 7
        #10 digit_in = 3'b100;  // 4
        #10 digit_in = 3'b010;  // 2
        #10 digit_in = 3'b001;  // 1
        #10 digit_in = 3'b111;  // 7
        #10 digit_in = 3'b011;  // 3
        #10 digit_in = 3'b100;  // 4
        #10 digit_in = 3'b101;  // 5
        #10 digit_in = 3'b100;  // 4
        #10 digit_in = 3'b010;  // 2
        #10 digit_in = 3'b001;  // 1
        #10 digit_in = 3'b111;  // 7
        #10 digit_in = 3'b100;  // 4
        #10 digit_in = 3'b000;  // 0
        #10 digit_in = 3'b101;  // 5

        // 시뮬레이션 종료
        #20 
        $fclose(file);  
        $finish;
    end
    assign code = {1'b0,code_in[11:9],1'b0,code_in[8:6],1'b0,code_in[5:3], 1'b0,code_in[2:0]};
    // 결과 모니터링
    always @(posedge clk) begin
        $fdisplay(file,"Time=%3t, code = %h, digit_in=%d, match=%b", $time, code, digit_in, match);
    end

endmodule