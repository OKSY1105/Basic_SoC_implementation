`timescale 1ns / 1ps

module testbench;

  // 파라미터 정의 (순수 Verilog 호환)
  parameter DATA_WIDTH = 8;
  parameter NUM_PATHS  = 4;

  // 신호 선언
  reg                           tb_clk;
  reg                           tb_rst_n;
  reg  [DATA_WIDTH-1:0]         tb_din;
  reg                           tb_din_valid;
  reg  [DATA_WIDTH-1:0]         captured_din;
  wire [(DATA_WIDTH*NUM_PATHS)-1:0] tb_dout;
  wire                          tb_dout_valid;

  integer log_fd;

  // DUT 인스턴스화
  parallel_processor #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_PATHS(NUM_PATHS)
  ) u_dut (
    .i_clk           (tb_clk),
    .i_rst           (~tb_rst_n),
    .i_data_in       (tb_din),
    .i_data_valid    (tb_din_valid),
    .o_data_out      (tb_dout),
    .o_data_out_valid(tb_dout_valid)
  );

  // 100MHz 클럭 생성 (5ns 토글)
  initial tb_clk = 1'b0;
  always #5 tb_clk = ~tb_clk;

  // 데이터 주입용 Task (integer 타입 사용)
  task drive_stimulus;
    input [DATA_WIDTH-1:0] val;
    input integer idle_cycles;
    begin
      repeat(idle_cycles) @(posedge tb_clk);
      tb_din       <= val;
      tb_din_valid <= 1'b1;
      @(posedge tb_clk);
      tb_din_valid <= 1'b0;
    end
  endtask

  // 메인 시퀀스 제어
  initial begin
    $timeformat(-9, 0, "ns", 0);
    log_fd = $fopen("output.txt", "w");

    // 초기화 및 리셋 (20ns 유지)
    tb_rst_n     = 1'b0;
    tb_din       = {DATA_WIDTH{1'b0}};
    tb_din_valid = 1'b0;

    #20;
    tb_rst_n     = 1'b1;

    // 테스트 벡터 인가
    drive_stimulus(8'h55, 1);  // 30ns~40ns
    drive_stimulus(8'haa, 2);  // 60ns~70ns
    drive_stimulus(8'hff, 2);  // 90ns~100ns

    #30;
    $fclose(log_fd);
    $finish;
  end

  // 입력 데이터 동기화 래치
  always @(posedge tb_clk) begin
    if (tb_din_valid) begin
      captured_din <= tb_din;
    end
  end

  // 결과 검증 및 파일 출력 (Falling edge 샘플링)
  always @(negedge tb_clk) begin
    if (tb_rst_n && tb_dout_valid) begin
      $fdisplay(log_fd, "Time: %0t, Input: %02h, Output: %08h", $time, captured_din, tb_dout);
      $fdisplay(log_fd, "  Path 1: %02h", tb_dout[7:0]);
      $fdisplay(log_fd, "  Path 2: %02h", tb_dout[15:8]);
      $fdisplay(log_fd, "  Path 3: %02h", tb_dout[23:16]);
      $fdisplay(log_fd, "  Path 4: %02h", tb_dout[31:24]);
    end
  end

endmodule
