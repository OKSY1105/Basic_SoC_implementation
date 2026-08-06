`timescale 1ns / 1ps
module testbench;


    // 입력과 출력 신호 정의
    reg [7:0] data_in;
    wire [7:0] data_out;
    integer file;  

    // DUT (Device Under Test) 인스턴스화
    msb_one_extractor dut (
        .i_data_in(data_in),
        .o_data_out(data_out)
    );

    // 테스트 시나리오
    initial begin
        file = $fopen("output.txt", "w");
        // 테스트 케이스 1
        data_in = 8'b01100001;
        #10;
        $fdisplay(file,"Test Case 1: Input = %b, Output = %b", data_in, data_out);

        // 테스트 케이스 2
        data_in = 8'b00100101;
        #10;
        $fdisplay(file,"Test Case 2: Input = %b, Output = %b", data_in, data_out);

        // 테스트 케이스 3
        data_in = 8'b10000000;
        #10;
        $fdisplay(file,"Test Case 3: Input = %b, Output = %b", data_in, data_out);

        // 테스트 케이스 4
        data_in = 8'b00000001;
        #10;
        $fdisplay(file,"Test Case 4: Input = %b, Output = %b", data_in, data_out);

        // 테스트 케이스 5
        data_in = 8'b00000000;
        #10;
        $fdisplay(file,"Test Case 5: Input = %b, Output = %b", data_in, data_out);

        // 시뮬레이션 종료
        $fclose(file);  
        $finish;
    end

endmodule