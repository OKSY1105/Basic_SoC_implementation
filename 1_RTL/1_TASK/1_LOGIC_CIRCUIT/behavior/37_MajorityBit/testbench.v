`timescale 1ns / 1ps
module testbench;
 
    // 테스트할 모듈의 입출력 신호
    reg [7:0] input1;
    reg [7:0] input2;
    reg [7:0] input3;
    wire [7:0] result;
    integer file;  


    // 테스트할 모듈 인스턴스화
    bit_majority_analyzer uut (
        .i_in1(input1),
        .i_in2(input2),
        .i_in3(input3),
        .o_result(result)
    );

    // 테스트 케이스를 저장할 배열
    reg [7:0] test_inputs [0:2][0:4];  // 5개의 테스트 케이스, 각각 3개의 입력
    reg [7:0] expected_results [0:4];  // 5개의 테스트 케이스에 대한 예상 결과

    integer i;

    initial begin
        file = $fopen("output.txt", "w");
        // 테스트 케이스 초기화
        // 테스트 케이스 1
        test_inputs[0][0] = 8'b10101010; test_inputs[1][0] = 8'b11001100; test_inputs[2][0] = 8'b11110000;
        expected_results[0] = 8'b11101000;

        // 테스트 케이스 2
        test_inputs[0][1] = 8'b00000000; test_inputs[1][1] = 8'b11111111; test_inputs[2][1] = 8'b10101010;
        expected_results[1] = 8'b10101010;

        // 테스트 케이스 3
        test_inputs[0][2] = 8'b11111111; test_inputs[1][2] = 8'b11111111; test_inputs[2][2] = 8'b00000000;
        expected_results[2] = 8'b11111111;

        // 테스트 케이스 4
        test_inputs[0][3] = 8'b10101010; test_inputs[1][3] = 8'b01010101; test_inputs[2][3] = 8'b00000000;
        expected_results[3] = 8'b00000000;

        // 테스트 케이스 5
        test_inputs[0][4] = 8'b11001100; test_inputs[1][4] = 8'b00110011; test_inputs[2][4] = 8'b10101010;
        expected_results[4] = 8'b10101010;

        // 테스트 실행
        for (i = 0; i < 5; i = i + 1) begin
            input1 = test_inputs[0][i];
            input2 = test_inputs[1][i];
            input3 = test_inputs[2][i];

            #10; // 결과가 안정화될 시간을 줍니다.

            // 결과 확인 및 출력
            $fdisplay(file,"Test Case %0d:", i+1);
            $fdisplay(file,"  Input1: %b", input1);
            $fdisplay(file,"  Input2: %b", input2);
            $fdisplay(file,"  Input3: %b", input3);
            $fdisplay(file,"  Result: %b", result);
            $fdisplay(file,"  Expected: %b", expected_results[i]);
            
            if (result === expected_results[i])
                $fdisplay(file,"  Test Passed");
            else
                $fdisplay(file,"  Test Failed");
            
            $fdisplay(file,"");
        end

        $fclose(file);  
        $finish;
    end

endmodule