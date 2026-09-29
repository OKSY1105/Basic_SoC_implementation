`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (tb_ Prefix 적용)
  // ==========================================
  reg        tb_sys_clk;
  reg        tb_sys_rst;
  reg  [7:0] tb_cfg_time_val;
  reg        tb_pulse_cnt_en;

  wire [7:0] tb_cnt_out;
  wire [7:0] tb_decade_out;
  wire [7:0] tb_en_cnt_out;
  wire       tb_time_en_out;
  wire [7:0] tb_time_cnt_out;
  wire [4:0] tb_clock_hr;
  wire [5:0] tb_clock_min;
  wire [5:0] tb_clock_sec;

  integer    fd_log;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  counter u_counter (
    .i_clk       ( tb_sys_clk       ),
    .i_reset     ( tb_sys_rst       ),
    .i_time_val  ( tb_cfg_time_val  ),
    .i_cnt_en    ( tb_pulse_cnt_en  ),
    .o_cnt       ( tb_cnt_out       ),
    .o_decade    ( tb_decade_out    ),
    .o_en_cnt    ( tb_en_cnt_out    ),
    .o_time_en   ( tb_time_en_out   ),
    .o_time_cnt  ( tb_time_cnt_out  ),
    .o_clock_h   ( tb_clock_hr      ),
    .o_clock_m   ( tb_clock_min     ),
    .o_clock_s   ( tb_clock_sec     )
  );

  // ==========================================
  // 클록 생성 (10ns 주기 유지)
  // ==========================================
  initial begin
    tb_sys_clk = 1'b0;
    forever tb_sys_clk = #5 ~tb_sys_clk;
  end

  // ==========================================
  // 리셋 및 기본 설정 자극
  // ==========================================
  initial begin
    tb_cfg_time_val = 8'd30;
    tb_sys_rst      = 1'b0;
    #5;
    tb_sys_rst      = 1'b1;
    #5;
    tb_sys_rst      = 1'b0;
  end

  // ==========================================
  // 카운터 인에이블 펄스 생성
  // ==========================================
  initial begin
    fd_log          = $fopen("output.txt", "w");
    tb_pulse_cnt_en = 1'b0;

    while (1) begin
      repeat (5) @(posedge tb_sys_clk);
      #1 tb_pulse_cnt_en = 1'b1;
      @(posedge tb_sys_clk);
      #1 tb_pulse_cnt_en = 1'b0;
    end
  end

  // ==========================================
  // 결과 로깅 및 파일 기록
  // ==========================================
  always @(posedge tb_sys_clk) begin
    $fdisplay(fd_log, "i_reset = %d, o_cnt = %3d, o_decade = %2h, i_cnt_en = %1d, o_en_cnt = %3d, i_time_val = %2d, o_time_cnt = %2d, o_time_en = %1d, o_clock_h = %1d, o_clock_m = %2d, o_clock_s = %2d",
              tb_sys_rst, tb_cnt_out, tb_decade_out, tb_pulse_cnt_en, tb_en_cnt_out, tb_cfg_time_val, tb_time_cnt_out, tb_time_en_out, tb_clock_hr, tb_clock_min, tb_clock_sec);
    $fflush(fd_log);
  end

  // ==========================================
  // 시뮬레이션 종료 조건 감시
  // ==========================================
  initial begin
    wait (tb_clock_hr == 5'd1);
    @(posedge tb_sys_clk);
    #10;
    $fclose(fd_log);
    $finish;
  end

endmodule
