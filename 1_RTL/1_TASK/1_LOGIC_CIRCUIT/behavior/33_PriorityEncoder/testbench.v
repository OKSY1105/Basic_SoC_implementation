`timescale 1ns / 1ps

module testbench;

  // 테스트 신호 선언 (tb_ Prefix 적용)
  reg  [3:0] tb_enc_in;
  wire [1:0] tb_enc_out;
  wire       tb_valid_flag;

  integer    fd_log;
  integer    idx;

  // DUT 인스턴스화 (포트명: i_in, o_out, o_valid 유지)
  priority_encoder u_priority_encoder (
    .i_in    ( tb_enc_in     ),
    .o_out   ( tb_enc_out    ),
    .o_valid ( tb_valid_flag )
  );

  // ==========================================
  // 테스트 시퀀스 및 파일 기록
  // ==========================================
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 0(4'b0000)부터 15(4'b1111)까지 10ns 간격으로 인가
    for (idx = 0; idx < 16; idx = idx + 1) begin
      tb_enc_in = idx[3:0];
      #10; // 10ns 지연 시간 유지

      // 입출력 결과 기록 (원본 포맷 문자열 100% 일치)
      $fdisplay(fd_log, "Input: %b, Output: %b, Valid: %b", tb_enc_in, tb_enc_out, tb_valid_flag);

      // 우선순위 인코더 동작 검증 조건문
      if (tb_enc_in == 4'b0000 && tb_valid_flag == 1'b0) begin
        $fdisplay(fd_log, "Test case %d passed (all zeros)", idx);
      end else if (tb_enc_in[3] == 1'b1 && tb_enc_out == 2'b11 && tb_valid_flag == 1'b1) begin
        $fdisplay(fd_log, "Test case %d passed (priority 3)", idx);
      end else if (tb_enc_in[2] == 1'b1 && tb_enc_out == 2'b10 && tb_valid_flag == 1'b1) begin
        $fdisplay(fd_log, "Test case %d passed (priority 2)", idx);
      end else if (tb_enc_in[1] == 1'b1 && tb_enc_out == 2'b01 && tb_valid_flag == 1'b1) begin
        $fdisplay(fd_log, "Test case %d passed (priority 1)", idx);
      end else if (tb_enc_in[0] == 1'b1 && tb_enc_out == 2'b00 && tb_valid_flag == 1'b1) begin
        $fdisplay(fd_log, "Test case %d passed (priority 0)", idx);
      end else begin
        $fdisplay(fd_log, "Test case %d failed", idx);
      end
    end

    $fclose(fd_log);
    $finish;
  end

endmodule
