`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations (변경된 포트 스타일 반영)
    // ==========================================
    reg        i_clk;
    reg        i_rst_n;
    reg        i_en;
    reg  [7:0] i_data;
    
    wire [7:0] o_data_out;
    
    integer file;   

    // ==========================================
    // Module Instantiation (DU)
    // ==========================================
    clock_gating u_clock_gating (
        .i_clk      ( i_clk      ),
        .i_rst_n    ( i_rst_n    ),
        .i_en       ( i_en       ),
        .i_data     ( i_data     ),
        .o_data_out ( o_data_out )
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    always #5 i_clk = ~i_clk;

    // ==========================================
    // Test Stimulus
    // ==========================================
    initial begin
        // 초기화
        i_clk   = 0;
        i_rst_n = 0;
        i_en    = 0;
        i_data  = 8'h00;
        file    = $fopen("output.txt", "w");

        // 리셋 해제
        #20 i_rst_n = 1;

        // 테스트 1: i_en이 0일 때
        #7  i_data = 8'hAA;
        #20;

        // 테스트 2: i_en을 1로 설정
        i_en = 1;
        #20 i_data = 8'h55;
        #20;

        // 테스트 3: i_en을 다시 0으로 설정
        i_en = 0;
        #20 i_data = 8'hFF;
        #20;

        // 테스트 4: i_en을 다시 1로 설정
        i_en = 1;
        #20;

        // 파일 닫기 및 시뮬레이션 종료
        $fflush(file); // 마지막 출력 버퍼 저장
        $fclose(file);  
        #20 $finish;
    end

    // ==========================================
    // Logging & Monitoring
    // ==========================================
    always @(posedge i_clk) begin
        $fdisplay(file, "i_en=%b, i_data=%h, o_data_out=%h", 
                  i_en, i_data, o_data_out);
        $fflush(file); // 버퍼 비우기 (파일 잘림 방지)
    end

endmodule