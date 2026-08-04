`timescale 1ns / 1ps

module testbench;
    // 입력과 출력 신호 정의
    reg [3:0] in;
    wire [1:0] out;
    wire valid;
    integer file;   

    // 테스트할 모듈 인스턴스화 (변경된 포트 이름으로 연결)
    priority_encoder u_priority_encoder (
        .i_in(in),
        .o_out(out),
        .o_valid(valid)
    );

    // 테스트 벡터를 저장할 배열
    reg [3:0] test_vectors[15:0];
    integer i;

    initial begin
        file = $fopen("output.txt", "w");
        // 테스트 벡터 초기화
        test_vectors[0]  = 4'b0000;
        test_vectors[1]  = 4'b0001;
        test_vectors[2]  = 4'b0010;
        test_vectors[3]  = 4'b0011;
        test_vectors[4]  = 4'b0100;
        test_vectors[5]  = 4'b0101;
        test_vectors[6]  = 4'b0110;
        test_vectors[7]  = 4'b0111;
        test_vectors[8]  = 4'b1000;
        test_vectors[9]  = 4'b1001;
        test_vectors[10] = 4'b1010;
        test_vectors[11] = 4'b1011;
        test_vectors[12] = 4'b1100;
        test_vectors[13] = 4'b1101;
        test_vectors[14] = 4'b1110;
        test_vectors[15] = 4'b1111;

        // 모든 테스트 벡터에 대해 테스트 실행
        for (i = 0; i < 16; i = i + 1) begin
            in = test_vectors[i];
            #10; // 10ns 대기
            
            // 결과 확인 및 출력
            $fdisplay(file,"Input: %b, Output: %b, Valid: %b", in, out, valid);
            
            // 예상 결과와 비교
            if (in == 4'b0000 && valid == 1'b0)
                $fdisplay(file,"Test case %d passed (all zeros)", i);
            else if (in[3] == 1'b1 && out == 2'b11 && valid == 1'b1)
                $fdisplay(file,"Test case %d passed (priority 3)", i);
            else if (in[2] == 1'b1 && out == 2'b10 && valid == 1'b1)
                $fdisplay(file,"Test case %d passed (priority 2)", i);
            else if (in[1] == 1'b1 && out == 2'b01 && valid == 1'b1)
                $fdisplay(file,"Test case %d passed (priority 1)", i);
            else if (in[0] == 1'b1 && out == 2'b00 && valid == 1'b1)
                $fdisplay(file,"Test case %d passed (priority 0)", i);
            else
                $fdisplay(file,"Test case %d failed", i);
        end

        $fclose(file);  
        $finish; // 시뮬레이션 종료
    end

endmodule