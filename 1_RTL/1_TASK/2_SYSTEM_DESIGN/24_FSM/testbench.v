`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg         i_clk;
    reg         i_reset;
    reg         i_in;
    wire        o_out;
    integer     file;

    // ==========================================
    // Module Instantiation
    // ==========================================
    // fsm 모듈의 포트(i_clk, i_reset, i_in, o_out)에 1:1 정확히 매핑
    fsm u_fsm (
        .i_clk   ( i_clk   ),
        .i_reset ( i_reset ),
        .i_in    ( i_in    ),
        .o_out   ( o_out   )
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    initial i_clk = 0;
    always #5 i_clk = ~i_clk; // 10ns clock period

    // ==========================================
    // Test Stimulus
    // ==========================================
    reg [9:0] in_sequence = 10'b0111101110; // 원하는 입력 시퀀스
    integer i;

    initial begin
        file = $fopen("output.txt", "w");
        i_reset = 1;
        i_in <= 0;
        #12;
        i_reset = 0;

        for (i = 0; i < 10; i = i + 1) begin
            @(posedge i_clk);
            i_in <= in_sequence[i];
        end

        #20;
        $fclose(file); 
        $finish;
    end

    // ==========================================
    // Checker and Display
    // ==========================================
    reg [3:0] cycle_count = 0;

    always @(posedge i_clk) begin
        cycle_count <= cycle_count + 1;
        $fdisplay(file, "Cycle %0d: in = %b, out = %b", cycle_count, i_in, o_out);
    end

endmodule
