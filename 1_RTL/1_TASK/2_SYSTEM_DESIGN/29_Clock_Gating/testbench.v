`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (tb_ Prefix 적용)
  // ==========================================
  reg        tb_sys_clk;
  reg        tb_sys_rst_n;
  reg        tb_gate_en;
  reg  [7:0] tb_din;

  wire [7:0] tb_dout;

  integer    fd_log;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  clock_gating u_clock_gating (
    .i_clk      ( tb_sys_clk   ),
    .i_rst_n    ( tb_sys_rst_n ),
    .i_en       ( tb_gate_en   ),
    .i_data     ( tb_din       ),
    .o_data_out ( tb_dout      )
  );

  // ==========================================
  // 100MHz 클록 생성 (10ns 주기)
  // ==========================================
  always #5 tb_sys_clk = ~tb_sys_clk;

  // ==========================================
  // 자극 인가 시퀀스
  // ==========================================
  initial begin
    // 초기화
    tb_sys_clk   = 1'b0;
    tb_sys_rst_n = 1'b0;
    tb_gate_en   = 1'b0;
    tb_din       = 8'h00;
    fd_log       = $fopen("output.txt", "w");

    // 리셋 해제
    #20 tb_sys_rst_n = 1'b1;

    // 단계 1: 게이트 비활성화 상태 데이터 변경
    #7  tb_din = 8'hAA;
    #20;

    // 단계 2: 게이트 활성화 및 데이터 인가
    tb_gate_en = 1'b1;
    #20 tb_din = 8'h55;
    #20;

    // 단계 3: 게이트 비활성화 및 데이터 인가
    tb_gate_en = 1'b0;
    #20 tb_din = 8'hFF;
    #20;

    // 단계 4: 게이트 재활성화
    tb_gate_en = 1'b1;
    #20;

    // 시뮬레이션 완료 처리
    $fflush(fd_log);
    $fclose(fd_log);
    #20 $finish;
  end

  // ==========================================
  // 사이클 단위 로깅 블록
  // ==========================================
  always @(posedge tb_sys_clk) begin
    $fdisplay(fd_log, "i_en=%b, i_data=%h, o_data_out=%h",
              tb_gate_en, tb_din, tb_dout);
    $fflush(fd_log);
  end

endmodule
