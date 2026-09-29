`timescale 1ns / 1ps

module testbench;

  // 파라미터 정의
  localparam DATA_WIDTH = 32;

  // ==========================================
  // 신호 정의 (tb_ Prefix 적용)
  // ==========================================
  reg                   tb_sys_clk;
  reg                   tb_rst_n;
  reg  [DATA_WIDTH-1:0] tb_stage_din;

  wire [DATA_WIDTH-1:0] tb_pipe_stage1;
  wire [DATA_WIDTH-1:0] tb_pipe_stage2;
  wire [DATA_WIDTH-1:0] tb_pipe_stage3;
  wire [DATA_WIDTH-1:0] tb_pipe_stage4;
  wire [DATA_WIDTH-1:0] tb_pipe_stage5;

  integer               fd_out;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  pipeline #(DATA_WIDTH) u_stage_pipe (
    .i_clk   ( tb_sys_clk     ),
    .i_rst_n ( tb_rst_n       ),
    .i_data  ( tb_stage_din   ),
    .o_line1 ( tb_pipe_stage1 ),
    .o_line2 ( tb_pipe_stage2 ),
    .o_line3 ( tb_pipe_stage3 ),
    .o_line4 ( tb_pipe_stage4 ),
    .o_line5 ( tb_pipe_stage5 )
  );

  // ==========================================
  // 클록 생성 (10ns 주기 유지)
  // ==========================================
  always #5 tb_sys_clk = ~tb_sys_clk;

  // ==========================================
  // 모니터링 및 파일 로깅 (동일 포맷 문자열)
  // ==========================================
  initial begin
    $fmonitor(fd_out, "i_data=%h o_line1=%h o_line2=%h o_line3=%h o_line4=%h o_line5=%h",
              tb_stage_din, tb_pipe_stage1, tb_pipe_stage2, tb_pipe_stage3, tb_pipe_stage4, tb_pipe_stage5);
  end

  // ==========================================
  // 자극 인가 시퀀스
  // ==========================================
  initial begin
    fd_out = $fopen("output.txt", "w");
    if (!fd_out) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 초기 상태 설정
    tb_sys_clk   = 1'b0;
    tb_rst_n     = 1'b0;
    tb_stage_din = {DATA_WIDTH{1'b0}};

    // 리셋 해제
    #10 tb_rst_n = 1'b1;

    // 파이프라인 스테이지 데이터 순차 주입
    @(posedge tb_sys_clk) tb_stage_din <= 32'h11111111;
    @(posedge tb_sys_clk) tb_stage_din <= 32'h22222222;
    @(posedge tb_sys_clk) tb_stage_din <= 32'h33333333;
    @(posedge tb_sys_clk) tb_stage_din <= 32'h44444444;
    @(posedge tb_sys_clk) tb_stage_din <= 32'h55555555;

    // 파이프라인 전파 대기
    repeat (6) @(posedge tb_sys_clk);

    $fflush(fd_out);
    $fclose(fd_out);
    $finish;
  end

endmodule
