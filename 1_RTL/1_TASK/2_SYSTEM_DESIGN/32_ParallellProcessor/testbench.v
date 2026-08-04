`timescale 1ns / 1ps

module testbench;

  parameter DATA_WIDTH = 8;
  parameter NUM_PATHS  = 4;

  reg clk;
  reg rst;
  reg [DATA_WIDTH-1:0] data_in;
  reg data_valid;
  integer file;  

  wire [DATA_WIDTH*NUM_PATHS-1:0] data_out;
  wire data_out_valid;

  // DUT 인스턴스화
  parallel_processor #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_PATHS(NUM_PATHS)
  ) dut (
    .i_clk(clk),
    .i_rst(rst),
    .i_data_in(data_in),
    .i_data_valid(data_valid),
    .o_data_out(data_out),
    .o_data_out_valid(data_out_valid)
  );

  // 100MHz 클럭 생성 (주기 10ns: 0ns(L), 5ns(H), 10ns(L)...)
  always #5 clk = ~clk;

  // 테스트 시나리오
  initial begin
    $timeformat(-9, 0, "ns", 6);
    file = $fopen("answer.txt", "w");

    // 초기화
    clk = 0;
    rst = 1;
    data_in = 0;
    data_valid = 0;

    // 리셋 해제
    #20;
    rst = 0;

    // 테스트 케이스 1: 0x55 (30ns~40ns 구간 입력)
    #10;
    data_in = 8'h55;
    data_valid = 1;
    #10;
    data_valid = 0;

    // 테스트 케이스 2: 0xAA (60ns~70ns 구간 입력)
    #20;
    data_in = 8'hAA;
    data_valid = 1;
    #10;
    data_valid = 0;

    // 테스트 케이스 3: 0xFF (90ns~100ns 구간 입력)
    #20;
    data_in = 8'hFF;
    data_valid = 1;
    #10;
    data_valid = 0;

    // 시뮬레이션 종료
    #30;
    $fclose(file);  
    $finish;
  end

  // 결과 모니터링: negedge clk에서 캡처하여 정확히 45ns, 75ns, 105ns 시점에 출력 기록!
  always @(negedge clk) begin
    if (!rst && data_out_valid) begin
      $fdisplay(file, "Time: %0t, Input: %h, Output: %h", $time, data_in, data_out);
      $fdisplay(file, "  Path 1: %h", data_out[DATA_WIDTH-1:0]);
      $fdisplay(file, "  Path 2: %h", data_out[DATA_WIDTH*2-1:DATA_WIDTH]);
      $fdisplay(file, "  Path 3: %h", data_out[DATA_WIDTH*3-1:DATA_WIDTH*2]);
      $fdisplay(file, "  Path 4: %h", data_out[DATA_WIDTH*4-1:DATA_WIDTH*3]);
    end
  end

endmodule
