`timescale 1ns / 1ps

module testbench;

  // 파라미터 정의
  parameter MEM_DEPTH  = 256;
  parameter DATA_WIDTH = 8;

  // 비트 폭 계산 함수 (while문 기반으로 재구성)
  function integer get_addr_width;
    input integer depth_val;
    integer temp;
    begin
      get_addr_width = 0;
      temp = depth_val - 1;
      while (temp > 0) begin
        get_addr_width = get_addr_width + 1;
        temp = temp >> 1;
      end
    end
  endfunction

  localparam ADDR_WIDTH = get_addr_width(MEM_DEPTH);

  // 테스트 신호 선언
  reg                    tb_clk;
  reg                    tb_rst;
  reg                    tb_we;
  reg  [ADDR_WIDTH-1:0]  tb_addr;
  reg  [DATA_WIDTH-1:0]  tb_din;
  wire [DATA_WIDTH-1:0]  tb_dout;

  integer log_fd;
  integer err_cnt;

  // DUT 인스턴스화
  clog2 #(
    .DEPTH(MEM_DEPTH)
  ) u_dut (
    .i_clk   (tb_clk),
    .i_rst   (tb_rst),
    .i_we    (tb_we),
    .i_addr  (tb_addr),
    .i_din   (tb_din),
    .o_dout  (tb_dout)
  );

  // 100MHz 클럭 생성 (5ns 반주기)
  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk;
  end

  // 검증용 Task
  task check_data;
    input [ADDR_WIDTH-1:0] target_addr;
    input [DATA_WIDTH-1:0] exp_val;
    begin
      @(posedge tb_clk);
      tb_addr <= target_addr;
      tb_we   <= 1'b0;
      @(posedge tb_clk);
      #1;
      if (tb_dout !== exp_val) begin
        $fdisplay(log_fd, "Error: Address %0d, Expected %0h, Got %0h", target_addr, exp_val, tb_dout);
        err_cnt = err_cnt + 1;
      end else begin
        $fdisplay(log_fd, "Success: Address %0d, Data %0h", target_addr, tb_dout);
      end
    end
  endtask

  // 메인 테스트 시퀀스
  initial begin
    log_fd = $fopen("output.txt", "w");

    // 신호 초기화
    err_cnt = 0;
    tb_rst  = 1'b1;
    tb_we   = 1'b0;
    tb_addr = {ADDR_WIDTH{1'b0}};
    tb_din  = {DATA_WIDTH{1'b0}};

    // 리셋 해제 및 초기 상태 확인
    #10 tb_rst = 1'b0;
    check_data(0, 8'h00);
    check_data(MEM_DEPTH - 1, 8'h00);

    // 데이터 쓰기 동작
    @(posedge tb_clk) begin
      tb_we   <= 1'b1;
      tb_addr <= 5;
      tb_din  <= 8'hA5;
    end
    @(posedge tb_clk) begin
      tb_we   <= 1'b1;
      tb_addr <= 10;
      tb_din  <= 8'h5A;
    end
    @(posedge tb_clk) begin
      tb_we   <= 1'b0;
    end

    // 데이터 읽기 검증
    check_data(5, 8'hA5);
    check_data(10, 8'h5A);

    // 미기록 영역 확인 (기본값 0x00)
    check_data(15, 8'h00);

    // 주소 비트 수 출력
    $fdisplay(log_fd, "Address width: %0d bits", get_addr_width(MEM_DEPTH));

    // 최종 결과 집계
    if (err_cnt == 0)
      $fdisplay(log_fd, "All tests passed successfully!");
    else
      $fdisplay(log_fd, "Tests completed with %0d errors.", err_cnt);

    #10;
    $fclose(log_fd);
    $finish;
  end

endmodule
