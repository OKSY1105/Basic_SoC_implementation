`timescale 1ns / 1ps

module testbench;

  // 신호 정의 (표준 프리픽스 적용)
  reg     tb_clk;
  reg     tb_rst_async;
  reg     tb_sig_in;
  wire    tb_fsm_state;

  integer fd_log;

  // DUT 인스턴스화 (포트 매핑 유지)
  fsm u_fsm (
    .i_clk    (tb_clk),
    .i_areset (tb_rst_async),
    .i_in     (tb_sig_in),
    .o_fsm    (tb_fsm_state)
  );

  // 클록 생성기 (주기 10ns, 반주기 5ns)
  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk;
  end

  // 초기 비동기 리셋 펄스
  initial begin
    tb_rst_async = 1'b1;
    #6 tb_rst_async = 1'b0;
  end

  // 모니터링 및 로깅 프로세스
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    while (1) begin
      @(posedge tb_clk);
      $display("areset=%b | in=%d | out_fsm=%b   ", tb_rst_async, tb_sig_in, tb_fsm_state);
      $fdisplay(fd_log, "areset=%b | in=%d | out_fsm=%b   ", tb_rst_async, tb_sig_in, tb_fsm_state);
    end
  end

  // 테스트 시나리오 시퀀스
  initial begin
    tb_sig_in = 1'b0;

    // 시나리오 1
    #20;
    #10 tb_sig_in = 1'b1;
    #10 tb_sig_in = 1'b0;

    // 시나리오 2
    #20;
    #10 tb_sig_in = 1'b1;
    #10 tb_sig_in = 1'b0;

    // 시나리오 3
    #30;
    #10 tb_sig_in = 1'b1;
    #10 tb_sig_in = 1'b0;

    // 비동기 리셋 재인가 테스트
    #20;
    #10 tb_rst_async = 1'b1;
    #10 tb_rst_async = 1'b0;

    // 시뮬레이션 완료
    #10;
    $fclose(fd_log);
    $finish;
  end

endmodule
