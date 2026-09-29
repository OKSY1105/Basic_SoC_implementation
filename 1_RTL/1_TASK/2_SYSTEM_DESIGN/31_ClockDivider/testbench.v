`timescale 1ns / 1ps

module testbench;
    // 동작 파라미터 정의
    localparam integer CLK_SRC_HZ   = 100_000_000; // 100 MHz
    localparam integer CLK_TGT_HZ   = 25_000_000;  // 25 MHz
    localparam integer T_IN_NS      = 1_000_000_000 / CLK_SRC_HZ; // 10 ns
    localparam integer T_OUT_NS     = 1_000_000_000 / CLK_TGT_HZ; // 40 ns

    // 테스트벤치 신호
    reg  tb_clk_in  = 1'b0;
    reg  tb_rst_n   = 1'b0;
    wire tb_clk_out;
    integer fd_out;

    // 분주기 인스턴스
    clock_divider #(
        .INPUT_FREQ(CLK_SRC_HZ),
        .OUTPUT_FREQ(CLK_TGT_HZ)
    ) u_dut (
        .i_clk(tb_clk_in),
        .i_rst_n(tb_rst_n),
        .o_clk(tb_clk_out)
    );

    // 100MHz 입력 클럭 생성
    always #(T_IN_NS / 2) tb_clk_in = ~tb_clk_in;

    // 시뮬레이션 제어 시퀀스
    initial begin
        fd_out = $fopen("output.txt", "w");

        // 리셋 시퀀스 (10 사이클 유지 후 해제)
        tb_rst_n = 1'b0;
        #(T_IN_NS * 10);
        tb_rst_n = 1'b1;

        // 20 사이클 동안 출력 관찰 후 종료
        #(T_OUT_NS * 20);
        $fclose(fd_out);
        $finish;
    end

    // 타이밍 측정 변수
    real t_rise_prev = 0.0;
    real t_fall_prev = 0.0;
    real t_cycle     = 0.0;
    real t_high      = 0.0;
    real duty_val    = 0.0;

    // 하강 에지 타임스탬프 기록
    always @(negedge tb_clk_out) begin
        t_fall_prev = $realtime;
    end

    // 상승 에지 주기 및 듀티비 연산/검증
    always @(posedge tb_clk_out) begin
        if (t_rise_prev > 0.0) begin
            t_cycle  = $realtime - t_rise_prev;
            t_high   = t_fall_prev - t_rise_prev;
            duty_val = (t_high / t_cycle) * 100.0;

            // 원본과 동일한 포맷 기록
            $fdisplay(fd_out, "Output clock period = %0d ns, Duty cycle = %0.2f%%", 
                      t_cycle, duty_val);

            // 오차 검증 및 경고 출력
            if (t_cycle < (T_OUT_NS * 0.99) || t_cycle > (T_OUT_NS * 1.01)) begin
                $fdisplay(fd_out, "Warning: Unexpected output clock period. Expected %0d ns", T_OUT_NS);
            end

            if (duty_val < 49.0 || duty_val > 51.0) begin
                $fdisplay(fd_out, "Warning: Duty cycle is out of 49-51% range");
            end
        end
        t_rise_prev = $realtime;
    end

endmodule
