`timescale 1ns / 1ps
module testbench;
 
      // 8비트 가산기를 위한 신호
    reg [7:0] a_8bit;
    reg [7:0] b_8bit;
    wire [8:0] sum_8bit;

    // 16비트 가산기를 위한 신호
    reg [15:0] a_16bit;
    reg [15:0] b_16bit;
    wire [16:0] sum_16bit;
    integer file;  

    // 가산기 인스턴스화
    parallel_adder #(.N(8)) uut_8bit (.i_a(a_8bit), .i_b(b_8bit), .o_sum(sum_8bit));
    parallel_adder #(.N(16)) uut_16bit (.i_a(a_16bit), .i_b(b_16bit), .o_sum(sum_16bit));

    // 테스트 벡터
    reg [15:0] test_vectors [0:7];
    integer i;

    // 테스트 시나리오
    initial begin
        file = $fopen("output.txt", "w");
        // 테스트 벡터 초기화
        test_vectors[0] = 16'h0000;  // 0
        test_vectors[1] = 16'h00FF;  // 255
        test_vectors[2] = 16'hFF00;  // 65280
        test_vectors[3] = 16'hFFFF;  // 65535
        test_vectors[4] = 16'h5555;  // 21845
        test_vectors[5] = 16'hAAAA;  // 43690
        test_vectors[6] = 16'h1234;  // 4660
        test_vectors[7] = 16'h7FFF;  // 32767

        // 기본 테스트 실행
        for (i = 0; i < 8; i = i + 1) begin
            a_8bit = test_vectors[i][7:0];
            b_8bit = test_vectors[(i+1) % 8][7:0];
            a_16bit = test_vectors[i];
            b_16bit = test_vectors[(i+1) % 8];

            #10;
            
            $fdisplay(file,"8-bit  Test Case %0d: a = %6d, b = %6d, sum = %6d", i+1, a_8bit, b_8bit, sum_8bit);
            $fdisplay(file,"16-bit Test Case %0d: a = %6d, b = %6d, sum = %6d", i+1, a_16bit, b_16bit, sum_16bit);
        end

        // 추가 테스트 케이스

        // 큰 수와 작은 수의 덧셈
        a_8bit = 8'hFE;  // 254
        b_8bit = 8'h01;  // 1
        #10;
        $fdisplay(file,"8-bit  Large + Small: a = %6d, b = %6d, sum = %6d", a_8bit, b_8bit, sum_8bit);

        a_16bit = 16'hFFFE;  // 65534
        b_16bit = 16'h0001;  // 1
        #10;
        $fdisplay(file,"16-bit Large + Small: a = %6d, b = %6d, sum = %6d", a_16bit, b_16bit, sum_16bit);


        // 최대값 근처의 덧셈
        a_8bit = 8'h7F;  // 127
        b_8bit = 8'h7E;  // 126
        #10;
        $fdisplay(file,"8-bit  Near Max: a = %6d, b = %6d, sum = %6d", a_8bit, b_8bit, sum_8bit);

        a_16bit = 16'h7FFE;  // 32766
        b_16bit = 16'h7FFE;  // 32766
        #10;
        $fdisplay(file,"16-bit Near Max: a = %6d, b = %6d, sum = %6d", a_16bit, b_16bit, sum_16bit);

        // 오버플로우 테스트
        a_8bit = 8'hFF;  // 255
        b_8bit = 8'h01;  // 1
        #10;
        $fdisplay(file,"8-bit  Overflow Test: a = %6d, b = %6d, sum = %6d", a_8bit, b_8bit, sum_8bit);

        a_16bit = 16'hFFFF;  // 65535
        b_16bit = 16'h0001;  // 1
        #10;
        $fdisplay(file,"16-bit Overflow Test: a = %6d, b = %6d, sum = %6d", a_16bit, b_16bit, sum_16bit);

        $fdisplay(file,"Test completed");
        $fclose(file);  
        $finish;
    end

endmodule