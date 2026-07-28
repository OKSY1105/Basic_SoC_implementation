`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg  [31:0] i_a;
    reg  [31:0] i_b;
    reg  [3:0]  i_op;

    wire [31:0] o_result;
    wire        o_zero;
    wire        o_overflow;

    integer file;   

    // ==========================================
    // Module Instantiation
    // ==========================================
    alu_32b u_alu_32b (
        .i_a        ( i_a        ),
        .i_b        ( i_b        ),
        .i_op       ( i_op       ),
        .o_result   ( o_result   ),
        .o_zero     ( o_zero     ),
        .o_overflow ( o_overflow )
    );

    // ==========================================
    // Task for Logging & Checking
    // ==========================================
    task display_result;
        input [3:0]  op_in;
        input [31:0] a_in, b_in, expected;
        begin
            #10; // 결과 안정화 대기
            $fdisplay(file, "Op: %b, A: %h, B: %h, Result: %h, Expected: %h, Zero: %b, Overflow: %b", 
                      op_in, $signed(a_in), $signed(b_in), $signed(o_result), $signed(expected), o_zero, o_overflow);
            
            if (o_result !== expected) begin
                $fdisplay(file, "ERROR: Mismatch detected!");
            end
            
            $fflush(file); // 메모리 버퍼 비우기 (파일 잘림 방지)
        end
    endtask

    // ==========================================
    // Test Stimulus
    // ==========================================
    initial begin
        file = $fopen("output.txt", "w");

        // 테스트 케이스 1: 덧셈
        i_a = 32'd10; i_b = 32'd20; i_op = 4'b0000;
        display_result(i_op, i_a, i_b, 32'd30);

        // 테스트 케이스 2: 뺄셈
        i_a = 32'd30; i_b = 32'd15; i_op = 4'b0001;
        display_result(i_op, i_a, i_b, 32'd15);

        // 테스트 케이스 3: AND
        i_a = 32'hFF00FF00; i_b = 32'h0F0F0F0F; i_op = 4'b0010;
        display_result(i_op, i_a, i_b, 32'h0F000F00);

        // 테스트 케이스 4: OR
        i_a = 32'hFF00FF00; i_b = 32'h0F0F0F0F; i_op = 4'b0011;
        display_result(i_op, i_a, i_b, 32'hFF0FFF0F);

        // 테스트 케이스 5: XOR
        i_a = 32'hFF00FF00; i_b = 32'h0F0F0F0F; i_op = 4'b0100;
        display_result(i_op, i_a, i_b, 32'hF00FF00F);

        // 테스트 케이스 6: NOT (answer.txt 포맷에 맞게 i_b 유지)
        i_a = 32'hFF00FF00; i_b = 32'h0F0F0F0F; i_op = 4'b0101; // ★ i_b = 32'h0F0F0F0F 로 수정
        display_result(i_op, i_a, i_b, 32'h00FF00FF);

        // 테스트 케이스 7: 논리 좌측 시프트
        i_a = 32'h0000FFFF; i_b = 32'd4; i_op = 4'b0110;
        display_result(i_op, i_a, i_b, 32'h000FFFF0);

        // 테스트 케이스 8: 논리 우측 시프트
        i_a = 32'hFF000000; i_b = 32'd4; i_op = 4'b0111;
        display_result(i_op, i_a, i_b, 32'h0FF00000);

        // 테스트 케이스 9: 산술 우측 시프트
        i_a = 32'h80000000; i_b = 32'd1; i_op = 4'b1000;
        display_result(i_op, i_a, i_b, 32'hC0000000);

        // 테스트 케이스 10: 부호 있는 비교 (SLT)
        i_a = -32'd10; i_b = 32'd5; i_op = 4'b1001;
        display_result(i_op, i_a, i_b, 32'd1);

        // 테스트 케이스 11: 부호 없는 비교 (SLTU)
        i_a = 32'hFFFFFFFF; i_b = 32'd1; i_op = 4'b1010;
        display_result(i_op, i_a, i_b, 32'd0);

        // 테스트 케이스 12: 오버플로우 테스트 (덧셈)
        i_a = 32'h7FFFFFFF; i_b = 32'd1; i_op = 4'b0000;
        display_result(i_op, i_a, i_b, 32'h80000000);

        // 테스트 케이스 13: 오버플로우 테스트 (뺄셈)
        i_a = 32'h80000000; i_b = 32'd1; i_op = 4'b0001;
        display_result(i_op, i_a, i_b, 32'h7FFFFFFF);

        // 테스트 케이스 14: 제로 플래그 테스트
        i_a = 32'd0; i_b = 32'd0; i_op = 4'b0000;
        display_result(i_op, i_a, i_b, 32'd0);

        $fclose(file);  
        $finish;
    end

endmodule
