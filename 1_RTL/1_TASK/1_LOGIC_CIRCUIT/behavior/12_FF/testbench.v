`timescale 1ns / 1ps

module tb_flip_flop;

  // 내부 신호 정의
  reg  tb_clk;
  reg  tb_rst_n;
  reg  tb_data_in;
  wire tb_data_out;

  integer fd_log;

  // DUT 연결 (포트 매핑: i_clk, i_reset, i_in, o_out)
  flipflop dut (
    .i_clk   (tb_clk),
    .i_reset (tb_rst_n),
    .i_in    (tb_data_in),
    .o_out   (tb_data_out)
  );

  // 100MHz 클록 (주기 10ns)
  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk;
  end

  // 로그 파일 기록 및 콘솔 출력
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: output.txt 파일을 열 수 없습니다.");
      $finish;
    end

    while (1) begin
      @(posedge tb_clk);
      $display("reset = %d, d=%b, q=%b ", tb_rst_n, tb_data_in, tb_data_out);
      $fdisplay(fd_log, "reset = %d, d=%b, q=%b ", tb_rst_n, tb_data_in, tb_data_out);
    end
  end

  // Stimulus 인가 시퀀스
  initial begin
    tb_rst_n   = 1'b1;
    tb_data_in = 1'b0;

    @(posedge tb_clk);
    #1 tb_rst_n <= 1'b0;

    @(posedge tb_clk);
    tb_data_in <= 1'b1;

    @(posedge tb_clk);
    tb_data_in <= 1'b0;

    @(posedge tb_clk);
    #1 tb_rst_n <= 1'b1;

    @(posedge tb_clk);
    tb_data_in <= 1'b1;

    @(posedge tb_clk);
    #1 tb_rst_n <= 1'b0;

    @(posedge tb_clk);
    tb_data_in <= 1'b0;

    @(posedge tb_clk);
    #10;

    $fclose(fd_log);
    $finish;
  end

endmodule
