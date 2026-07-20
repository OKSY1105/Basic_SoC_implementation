`timescale 1ns / 1ps

module testbench;

    reg        clk;
    reg        areset;
    reg        count_down_start;
    wire [3:0] out_count_up;   
    wire [3:0] out_count_down;   
    integer file;  

    // 새 포트 이름(i_*, o_*)에 맞춰 매핑 수정
    counter u_counter (
        .i_clk               ( clk              ),
        .i_reset             ( areset           ),
        .i_counter_down_start( count_down_start ),
        .o_counter_up        ( out_count_up     ),
        .o_counter_down      ( out_count_down   )
    );

    // 클록 생성
    initial begin
        clk = 0;
        forever clk = #5 ~clk;
    end

    // 리셋 인과
    initial begin
        areset = 0;
        #6;
        areset = 1;
        #6;
        areset = 0;
    end

    // 파일 출력 및 콘솔 디스플레이
    initial begin
        file = $fopen("output.txt", "w");
        forever begin
            @(posedge clk);
            $display("start = %d, count_up = %d count_down = %d", count_down_start, out_count_up, out_count_down);
            $fdisplay(file, "start = %d, count_up = %d count_down = %d", count_down_start, out_count_up, out_count_down);
        end
    end

    // 테스트 시퀀스
    initial begin
        count_down_start <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        count_down_start <= 0;
        @(posedge clk);
        count_down_start <= 1;
        @(posedge clk);
        count_down_start <= 0;
        @(posedge clk);
        
        wait(out_count_down == 4'd0);
        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        #5;
        $fclose(file);
        $finish;
    end

endmodule
