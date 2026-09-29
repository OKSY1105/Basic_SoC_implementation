`timescale 1ns / 1ps

module testbench;

  // 테스트 신호 선언 (tb_ Prefix 적용)
  reg  [7:0] tb_val_in;
  wire [7:0] tb_val_out;

  integer    fd_log;

  // DUT 인스턴스화 (포트명 유지)
  msb_one_extractor u_msb_extractor (
    .i_data_in  ( tb_val_in  ),
    .o_data_out ( tb_val_out )
  );

  // ==========================================
  // 테스트 케이스 실행 및 로깅 태스크
  // ==========================================
  task execute_case;
    input integer tc_id;
    input [7:0]   stimulus_data;
    begin
      tb_val_in = stimulus_data;
      #10; // 결과 안정화 지연
      $fdisplay(fd_log, "Test Case %0d: Input = %b, Output = %b", tc_id, tb_val_in, tb_val_out);
    end
  endtask

  // ==========================================
  // 테스트 시나리오 시퀀스
  // ==========================================
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 테스트 케이스 1 ~ 5 인가
    execute_case(1, 8'b01100001);
    execute_case(2, 8'b00100101);
    execute_case(3, 8'b10000000);
    execute_case(4, 8'b00000001);
    execute_case(5, 8'b00000000);

    $fclose(fd_log);
    $finish;
  end

endmodule
