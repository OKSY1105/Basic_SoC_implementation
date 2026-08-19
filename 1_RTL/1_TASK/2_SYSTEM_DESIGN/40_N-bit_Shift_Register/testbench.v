`timescale 1ns / 1ps

module testbench;

    // 파라미터 정의
    parameter N = 8;

    // 비트 폭 계산 함수 (Verilog-2001 호환용 $clog2 대체)
    function integer calc_shift_bits;
        input integer val;
        integer cnt;
        begin
            cnt = 0;
            while ((1 << cnt) < val) begin
                cnt = cnt + 1;
            end
            calc_shift_bits = cnt;
        end
    endfunction

    localparam SHIFT_WIDTH = calc_shift_bits(N) + 1;

    // 테스트 신호 선언
    reg                    tb_clk;
    reg                    tb_rst;
    reg  [N-1:0]           tb_din;
    reg  [SHIFT_WIDTH-1:0] tb_shift_len;
    reg                    tb_dir;
    wire [N-1:0]           tb_dout;

    integer log_fd;

    // DUT 인스턴스화
    shift_register #(
        .N(N)
    ) u_shift_reg (
        .i_clk          (tb_clk),
        .i_rst          (tb_rst),
        .i_data_in      (tb_din),
        .i_shift_length (tb_shift_len),
        .i_dir          (tb_dir),
        .o_data_out     (tb_dout)
    );

    // 100MHz 클럭 생성 (5ns 토글)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    // 시프트 테스트 및 파일 로깅 태스크
    task execute_shift_test;
        input integer     tc_num;
        input             direction;
        input [SHIFT_WIDTH-1:0] len;
        input [8*35:1]    description;
        begin
            #10;
            tb_dir       = direction;
            tb_shift_len = len;
            #10;
            $fdisplay(log_fd, "Test Case %0d: %0s - Input: %b, Output: %b", tc_num, description, tb_din, tb_dout);
        end
    endtask

    // 테스트 시퀀스
    initial begin
        log_fd = $fopen("output.txt", "w");

        // 초기 상태 설정
        tb_rst       = 1'b1;
        tb_din       = 8'b10101010;
        tb_shift_len = {SHIFT_WIDTH{1'b0}};
        tb_dir       = 1'b0;

        // 리셋 해제 (10ns 유지)
        #10 tb_rst = 1'b0;

        // 테스트 케이스 실행 (기존 출력 포맷 문자열 100% 일치)
        execute_shift_test(1, 1'b0, 2, "Left shift 2 bits");
        execute_shift_test(2, 1'b1, 3, "Right shift 3 bits");
        execute_shift_test(3, 1'b0, 8, "Left shift 8 bits");
        execute_shift_test(4, 1'b1, 1, "Right shift 1 bit");
        execute_shift_test(5, 1'b0, 0, "No shift");

        // 시뮬레이션 종료
        #10;
        $fclose(log_fd);
        $finish;
    end

endmodule
