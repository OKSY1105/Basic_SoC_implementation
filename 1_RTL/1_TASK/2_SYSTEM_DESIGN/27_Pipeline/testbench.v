`timescale 1ns / 1ps

module testbench;
    parameter WIDTH = 32;
    
    // ==========================================
    // Signal Declarations (포트명 스타일 반영)
    // ==========================================
    reg  i_clk;
    reg  i_rst_n;
    reg  [WIDTH-1:0] i_data;
    
    wire [WIDTH-1:0] o_line1;
    wire [WIDTH-1:0] o_line2;
    wire [WIDTH-1:0] o_line3;
    wire [WIDTH-1:0] o_line4;
    wire [WIDTH-1:0] o_line5;
    
    integer file;   

    // ==========================================
    // Module Instantiation (DU)
    // ==========================================
    pipeline #(WIDTH) u_stage_pipe (
        .i_clk   ( i_clk   ),
        .i_rst_n ( i_rst_n ),
        .i_data  ( i_data  ),
        .o_line1 ( o_line1 ),
        .o_line2 ( o_line2 ),
        .o_line3 ( o_line3 ),
        .o_line4 ( o_line4 ),
        .o_line5 ( o_line5 )
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    always #5 i_clk = ~i_clk;

    // ==========================================
    // Stimulus
    // ==========================================
    initial begin
        file = $fopen("output.txt", "w");
        i_clk   = 0;
        i_rst_n = 0;
        i_data  = 0;

        // 리셋 해제
        #10 i_rst_n = 1;

        // 테스트 데이터 입력
        @(posedge i_clk) i_data <= 32'h11111111;
        @(posedge i_clk) i_data <= 32'h22222222;
        @(posedge i_clk) i_data <= 32'h33333333;
        @(posedge i_clk) i_data <= 32'h44444444;
        @(posedge i_clk) i_data <= 32'h55555555;

        // 파이프라인이 채워질 때까지 대기
        repeat(6) @(posedge i_clk);

        $fflush(file); // 버퍼 비우기 (파일잘림 방지)
        $fclose(file);  
        $finish;
    end

    // ==========================================
    // Logging & Checker
    // ==========================================
    initial begin
        $fmonitor(file, "i_data=%h o_line1=%h o_line2=%h o_line3=%h o_line4=%h o_line5=%h",
                  i_data, o_line1, o_line2, o_line3, o_line4, o_line5);
    end

endmodule
