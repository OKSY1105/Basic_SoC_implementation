`timescale 1ns / 1ps

module testbench;

  // 신호 선언 (tb_ prefix 적용)
  reg        tb_clk;
  reg        tb_rst;
  reg        tb_cd_start;
  wire [3:0] tb_cnt_up;
  wire [3:0] tb_cnt_down;

  integer    fd_out;

  // DUT 인스턴스화 (포트 연결 유지)
  counter u_counter (
    .i_clk                (tb_clk),
    .i_reset              (tb_rst),
    .i_counter_down_start (tb_cd_start),
    .o_counter_up         (tb_cnt_up),
    .o_counter_down       (tb_cnt_down)
  );

  // 100MHz 클록 생성 (10ns 주기, 반주기 5ns)
  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk;
  end

  // 비동기 리셋 펄스 인가
  initial begin
    tb_rst = 1'b0;
    #6 tb_rst = 1'b1;
    #6 tb_rst = 1'b0;
  end

  // 결과 모니터링 및 파일 기록
  initial begin
    fd_out = $fopen("output.txt", "w");
    if (!fd_out) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    while (1) begin
      @(posedge tb_clk);
      $display("start = %d, count_up = %d count_down = %d", tb_cd_start, tb_cnt_up, tb_cnt_down);
      $fdisplay(fd_out, "start = %d, count_up = %d count_down = %d", tb_cd_start, tb_cnt_up, tb_cnt_down);
    end
  end

  // 자극(Stimulus) 시퀀스
  initial begin
    tb_cd_start <= 1'b0;
    repeat (3) @(posedge tb_clk);

    tb_cd_start <= 1'b0;
    @(posedge tb_clk);
    tb_cd_start <= 1'b1;
    @(posedge tb_clk);
    tb_cd_start <= 1'b0;
    @(posedge tb_clk);

    // 카운트다운 완료 대기
    wait (tb_cnt_down == 4'd0);

    repeat (6) @(posedge tb_clk);

    #5;
    $fclose(fd_out);
    $finish;
  end

endmodule
