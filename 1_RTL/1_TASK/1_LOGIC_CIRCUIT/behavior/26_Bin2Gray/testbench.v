`timescale 1ns / 1ps

module testbench;

  // 테스트 신호 선언
  reg  [3:0] tb_bin_data;
  wire [3:0] tb_gray_data;
  integer    fd_out;
  integer    idx;

  // DUT 인스턴스화 (파라미터 전달 구문 제거)
  bin_2_gray dut_b2g (
    .i_binary_in ( tb_bin_data  ),
    .o_gray_out  ( tb_gray_data )
  );

  // ==========================================
  // 시뮬레이션 및 파일 로깅
  // ==========================================
  initial begin
    fd_out = $fopen("output.txt", "w");
    if (!fd_out) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 원본과 동일한 포맷으로 모니터링
    $fmonitor(fd_out, "i_binary_in=%b o_gray_out=%b", tb_bin_data, tb_gray_data);

    // 0부터 15까지 10ns 간격 인가
    for (idx = 0; idx < 16; idx = idx + 1) begin
      tb_bin_data = idx[3:0];
      #10;
    end

    $fflush(fd_out);
    $fclose(fd_out);
    $finish;
  end

endmodule
