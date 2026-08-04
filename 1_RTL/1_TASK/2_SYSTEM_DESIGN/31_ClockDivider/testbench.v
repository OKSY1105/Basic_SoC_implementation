`timescale 1ns / 1ps

module testbench;
    // 테스트 파라미터
    localparam INPUT_FREQ   = 100_000_000;  // 100 MHz
    localparam OUTPUT_FREQ  = 25_000_000;   // 25 MHz
    localparam INPUT_PERIOD  = 1000000000 / INPUT_FREQ;   // 입력 클럭 주기 (ns)
    localparam OUTPUT_PERIOD = 1000000000 / OUTPUT_FREQ;  // 예상 출력 클럭 주기 (ns)

    // 테스트 신호
    reg clk_in;
    reg rst_n;
    wire clk_out;
    integer file;   

    // 클럭 분주기 인스턴스 (포트 이름 맞춤)
    clock_divider #(
        .INPUT_FREQ(INPUT_FREQ),
        .OUTPUT_FREQ(OUTPUT_FREQ)
    ) u_clock_divider (
        .i_clk(clk_in),
        .i_rst_n(rst_n),
        .o_clk(clk_out)
    );

    // 클럭 생성
    initial begin
        clk_in = 0;
        forever #(INPUT_PERIOD/2) clk_in = ~clk_in;
    end

    // 테스트 시나리오
    initial begin
        file = $fopen("output.txt", "w");
        // 초기화
        rst_n = 0;
        #(INPUT_PERIOD*10);
        rst_n = 1;

        // 출력 클럭 관찰
        #(OUTPUT_PERIOD*20);

        // 테스트 종료
        $fclose(file);  
        $finish;
    end

    // 출력 클럭 주기 및 듀티 사이클 체크
    real last_rise = 0;
    real last_fall = 0;
    real period = 0;
    real high_time = 0;
    real duty_cycle = 0;

    always @(posedge clk_out) begin
        if (last_rise != 0) begin
            period = $realtime - last_rise;
            
            // 내부 계산 시 음수/시점 오차 방지 보완
            high_time = last_fall - last_rise;
            duty_cycle = (high_time / period) * 100.0;

            // ★ 원본과 100% 동일한 파일 출력 포맷 (%0d ns, %0.2f%%)
            $fdisplay(file, "Output clock period = %0d ns, Duty cycle = %0.2f%%", 
                      period, duty_cycle);
            
            // 주기 검증
            if (period < OUTPUT_PERIOD*0.99 || period > OUTPUT_PERIOD*1.01) begin
                $fdisplay(file, "Warning: Unexpected output clock period. Expected %0d ns", OUTPUT_PERIOD);
            end
            
            // 듀티 사이클 검증
            if (duty_cycle < 49 || duty_cycle > 51) begin
                $fdisplay(file, "Warning: Duty cycle is out of 49-51% range");
            end
        end
        last_rise = $realtime;
    end

    always @(negedge clk_out) begin
        last_fall = $realtime;
    end

endmodule