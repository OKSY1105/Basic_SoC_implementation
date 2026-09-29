`timescale 1ns / 1ps

module testbench;

  // 신호 정의 (표준 프리픽스 적용)
  reg  [7:0] tb_data_in;
  wire       tb_parity_gen;
  wire       tb_parity_err;

  integer    fd_log;

  // 1. 패리티 생성기 DUT 인스턴스화 (포트명: i_data_in, o_parity_bit)
  parity_bit u_parity_bit (
    .i_data_in     (tb_data_in),
    .o_parity_bit  (tb_parity_gen)
  );

  // 2. 패리티 검사기 DUT 인스턴스화 (포트명: i_data_in, i_parity_bit, o_parity_error)
  // 원본 시나리오에 맞춰 i_parity_bit에 1'b1 인가
  parity_checker u_parity_checker (
    .i_data_in       (tb_data_in),
    .i_parity_bit    (1'b1),
    .o_parity_error  (tb_parity_err)
  );

  // 입출력 모니터링 및 로그 파일 기록
  initial begin
    while (1) begin
      @(tb_data_in);
      $display("data_in = %b, parity_bit = %d, parity_error = %d ", tb_data_in, tb_parity_gen, tb_parity_err);
      if (fd_log) begin
        $fdisplay(fd_log, "data_in = %b, parity_bit = %d, parity_error = %d ", tb_data_in, tb_parity_gen, tb_parity_err);
      end
    end
  end

  // 자극(Stimulus) 인가 시퀀스 (0부터 255까지 증가)
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 초기값 설정 및 안정화 대기
    tb_data_in = 8'd0;
    #5;

    // 1부터 255까지 1ns 간격 순회
    repeat (255) begin
      #1 tb_data_in = tb_data_in + 8'd1;
    end

    // 시뮬레이션 종료 처리
    #5;
    $fclose(fd_log);
    $finish;
  end

endmodule
