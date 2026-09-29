`timescale 1ns / 1ps

module testbench;

  // 테스트 신호 정의 (tb_ Prefix 적용)
  reg  [7:0] tb_data_1;
  reg  [7:0] tb_data_2;
  reg  [7:0] tb_data_3;
  wire [7:0] tb_maj_out;

  integer    fd_log;

  // DUT 인스턴스화 (포트명 유지)
  bit_majority_analyzer dut_maj (
    .i_in1    ( tb_data_1  ),
    .i_in2    ( tb_data_2  ),
    .i_in3    ( tb_data_3  ),
    .o_result ( tb_maj_out )
  );

  // ==========================================
  // 테스트 케이스 실행 및 로깅 태스크
  // ==========================================
  task run_test_case;
    input integer tc_num;
    input [7:0]   in1, in2, in3, exp_out;
    begin
      tb_data_1 = in1;
      tb_data_2 = in2;
      tb_data_3 = in3;
      #10; // 결과 안정화 대기

      // 원본과 100% 동일한 문자열 및 들여쓰기 구조로 기록
      $fdisplay(fd_log, "Test Case %0d:", tc_num);
      $fdisplay(fd_log, "  Input1: %b", tb_data_1);
      $fdisplay(fd_log, "  Input2: %b", tb_data_2);
      $fdisplay(fd_log, "  Input3: %b", tb_data_3);
      $fdisplay(fd_log, "  Result: %b", tb_maj_out);
      $fdisplay(fd_log, "  Expected: %b", exp_out);

      if (tb_maj_out === exp_out) begin
        $fdisplay(fd_log, "  Test Passed");
      end else begin
        $fdisplay(fd_log, "  Test Failed");
      end

      $fdisplay(fd_log, "");
    end
  endtask

  // ==========================================
  // 시뮬레이션 시퀀스
  // ==========================================
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 테스트 케이스 1
    run_test_case(1, 8'b10101010, 8'b11001100, 8'b11110000, 8'b11101000);

    // 테스트 케이스 2
    run_test_case(2, 8'b00000000, 8'b11111111, 8'b10101010, 8'b10101010);

    // 테스트 케이스 3
    run_test_case(3, 8'b11111111, 8'b11111111, 8'b00000000, 8'b11111111);

    // 테스트 케이스 4
    run_test_case(4, 8'b10101010, 8'b01010101, 8'b00000000, 8'b00000000);

    // 테스트 케이스 5
    run_test_case(5, 8'b11001100, 8'b00110011, 8'b10101010, 8'b10101010);

    $fclose(fd_log);
    $finish;
  end

endmodule
