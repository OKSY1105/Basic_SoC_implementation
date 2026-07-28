`timescale 1ns / 1ps

module testbench;
    parameter WIDTH = 4;
    
    // ==========================================
    // Signal Declarations
    // ==========================================
    reg  [WIDTH-1:0] i_binary_in; // 신호명 수정 (binary_in -> i_binary_in)
    wire [WIDTH-1:0] o_gray_out;  // 신호명 수정 (gray_out   -> o_gray_out)
    integer file;   

    // ==========================================
    // Module Instantiation (DU)
    // ==========================================
    bin_2_gray #(WIDTH) u_bin_2_gray (
        .i_binary_in ( i_binary_in ), // 변경된 포트명 연결
        .o_gray_out  ( o_gray_out  )  // 변경된 포트명 연결
    );

    // ==========================================
    // Stimulus & File Output
    // ==========================================
    initial begin
        file = $fopen("output.txt", "w");
        
        // 데이터 변화 감지 및 출력을 포맷에 맞게 수정
        $fmonitor(file, "i_binary_in=%b o_gray_out=%b", i_binary_in, o_gray_out);
        
        // 입력 값 자극 (Stimulus)
        i_binary_in = 4'b0000; #10;
        i_binary_in = 4'b0001; #10;
        i_binary_in = 4'b0010; #10;
        i_binary_in = 4'b0011; #10;
        i_binary_in = 4'b0100; #10;
        i_binary_in = 4'b0101; #10;
        i_binary_in = 4'b0110; #10;
        i_binary_in = 4'b0111; #10;
        i_binary_in = 4'b1000; #10;
        i_binary_in = 4'b1001; #10;
        i_binary_in = 4'b1010; #10;
        i_binary_in = 4'b1011; #10;
        i_binary_in = 4'b1100; #10;
        i_binary_in = 4'b1101; #10;
        i_binary_in = 4'b1110; #10;
        i_binary_in = 4'b1111; #10;
        
        $fflush(file); // 버퍼에 남아있는 출력 기록 비우기 (파일 잘림 방지)
        $fclose(file);  
        $finish;
    end

endmodule
