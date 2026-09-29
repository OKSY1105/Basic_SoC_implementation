`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (tb_ Prefix 적용)
  // ==========================================
  reg        tb_clk;
  reg        tb_rst_n_inv; // active-high reset
  reg        tb_serial_in;
  wire       tb_fsm_out;
  integer    fd_log;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  fsm u_fsm (
    .i_clk   ( tb_clk        ),
    .i_reset ( tb_rst_n_inv  ),
    .i_in    ( tb_serial_in  ),
    .o_out   ( tb_fsm_out    )
  );

  // ==========================================
  // 클록 생성 (10ns 주기)
  // ==========================================
  initial tb_clk = 1'b0;
  always #5 tb_clk = ~tb_clk;

  // ==========================================
  // 테스트 자극 시퀀스
  // ==========================================
  localparam [9:0] PATTERN_SEQ = 10'b0111101110;
  integer          bit_idx;

  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 리셋 초기화 시퀀스
    tb_rst_n_inv = 1'b1;
    tb_serial_in <= 1'b0;
    #12;
    tb_rst_n_inv = 1'b0;

    // 10비트 패턴 순차 인가
    for (bit_idx = 0; bit_idx < 10; bit_idx = bit_idx + 1) begin
      @(posedge tb_clk);
      tb_serial_in <= PATTERN_SEQ[bit_idx];
    end

    #20;
    $fclose(fd_log);
    $finish;
  end

  // ==========================================
  // 사이클 카운터 및 로깅 블록
  // ==========================================
  reg [3:0] tb_tick_cnt = 4'd0;

  always @(posedge tb_clk) begin
    tb_tick_cnt <= tb_tick_cnt + 4'd1;
    // 원본과 100% 동일한 문자열 서식으로 출력
    $fdisplay(fd_log, "Cycle %0d: in = %b, out = %b", tb_tick_cnt, tb_serial_in, tb_fsm_out);
  end

endmodule
