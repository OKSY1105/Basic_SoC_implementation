`timescale 1ns / 1ps

module testbench;

  // --------------------------------------------------
  // 내부 테스트 신호 선언 (변수명 리팩토링)
  // --------------------------------------------------
  reg        tb_clk;
  reg        tb_sync_rst;
  reg        tb_async_rst;
  reg  [7:0] tb_val_a;
  reg  [7:0] tb_val_b;

  wire [1:0]  tb_mux_sel;
  wire [7:0]  tb_sum_in;

  wire [7:0]  tb_data_o0;
  wire [7:0]  tb_data_o1;
  wire [7:0]  tb_data_o2;
  wire [7:0]  tb_data_o3;
  wire [7:0]  tb_data_o4;
  wire [15:0] tb_data_o5;
  wire [7:0]  tb_data_o6;

  integer     fd_log;

  // 조합 논리 신호 연결
  assign tb_mux_sel = tb_val_a[3:2];
  assign tb_sum_in  = tb_val_a + tb_val_b;

  // --------------------------------------------------
  // DUT 인스턴스화 (포트명 유지)
  // --------------------------------------------------
  register u_registers (
    .i_clk    ( tb_clk      ),
    .i_reset  ( tb_sync_rst ),
    .i_areset ( tb_async_rst),
    .i_sel    ( tb_mux_sel  ),
    .i_in     ( tb_sum_in   ),
    .o_out_0  ( tb_data_o0  ),
    .o_out_1  ( tb_data_o1  ),
    .o_out_2  ( tb_data_o2  ),
    .o_out_3  ( tb_data_o3  ),
    .o_out_4  ( tb_data_o4  ),
    .o_out_5  ( tb_data_o5  ),
    .o_out_6  ( tb_data_o6  )
  );

  // 100MHz 시뮬레이션 클록 (10ns 주기)
  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk;
  end

  // 카운터 및 동기식 리셋 생성 로직
  always @(posedge tb_clk) begin
    tb_sync_rst <= tb_val_a[2] ? 1'b1 : 1'b0;
    tb_val_a    <= tb_val_a + 8'd1;
  end

  always @(negedge tb_clk) begin
    tb_val_b <= tb_val_b + 8'd1;
  end

  // 비동기 리셋 타이밍 제어
  initial begin
    tb_val_a     = 8'd0;
    tb_val_b     = 8'd0;
    tb_sync_rst  = 1'b0;
    tb_async_rst = 1'b0;

    #36 tb_async_rst = 1'b1;
    #26 tb_async_rst = 1'b0;
    #66 tb_async_rst = 1'b1;
  end

  // 모니터링 및 파일 로깅 프로세스
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: output.txt open failed.");
      $finish;
    end

    // 파일 출력 형식은 원본 검증 시스템과 100% 동일 유지
    $fmonitor(fd_log, "i_clk = %d, i_reset = %d, i_areset = %d, i_in = %d, o_out_0 = %d, o_out_1 = %d, o_out_2 = %d, o_out_3 = %d, o_out_4 = %d, i_sel = %d, o_out_5 = %h, o_out_6 = %b",
              tb_clk, tb_sync_rst, tb_async_rst, tb_sum_in,
              tb_data_o0, tb_data_o1, tb_data_o2, tb_data_o3, tb_data_o4,
              tb_mux_sel, tb_data_o5, tb_data_o6);

    wait (tb_val_b == 8'd15);
    #10;

    $fclose(fd_log);
    $finish;
  end

endmodule
