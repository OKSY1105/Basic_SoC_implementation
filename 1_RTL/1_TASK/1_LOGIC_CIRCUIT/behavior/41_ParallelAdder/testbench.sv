`timescale 1ns / 1ps

module testbench;

  // 8-bit 가산기 테스트 신호
  reg  [7:0]  tb_a8;
  reg  [7:0]  tb_b8;
  wire [8:0]  tb_sum8;

  // 16-bit 가산기 테스트 신호
  reg  [15:0] tb_a16;
  reg  [15:0] tb_b16;
  wire [16:0] tb_sum16;

  integer     fd_log;
  integer     idx;

  // DUT 인스턴스화
  parallel_adder #(.N(8))  dut_adder8  (.i_a(tb_a8),  .i_b(tb_b8),  .o_sum(tb_sum8));
  parallel_adder #(.N(16)) dut_adder16 (.i_a(tb_a16), .i_b(tb_b16), .o_sum(tb_sum16));

  // 패턴 버퍼
  reg [15:0] pattern_table [0:7];

  // ==========================================
  // 테스트 케이스 실행 태스크
  // ==========================================
  task apply_custom_case;
    input [7:0]   a8_val, b8_val;
    input [15:0]  a16_val, b16_val;
    input [8*25:1] label_str;
    begin
      tb_a8  = a8_val;
      tb_b8  = b8_val;
      tb_a16 = a16_val;
      tb_b16 = b16_val;
      #10;
      $fdisplay(fd_log, "8-bit  %0s: a = %6d, b = %6d, sum = %6d", label_str, tb_a8, tb_b8, tb_sum8);
      $fdisplay(fd_log, "16-bit %0s: a = %6d, b = %6d, sum = %6d", label_str, tb_a16, tb_b16, tb_sum16);
    end
  endtask

  // ==========================================
  // 시뮬레이션 시퀀스
  // ==========================================
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 테스트 패턴 초기화
    pattern_table[0] = 16'h0000;
    pattern_table[1] = 16'h00FF;
    pattern_table[2] = 16'hFF00;
    pattern_table[3] = 16'hFFFF;
    pattern_table[4] = 16'h5555;
    pattern_table[5] = 16'hAAAA;
    pattern_table[6] = 16'h1234;
    pattern_table[7] = 16'h7FFF;

    // 1. 기본 순회 테스트 케이스 (8회)
    for (idx = 0; idx < 8; idx = idx + 1) begin
      tb_a8  = pattern_table[idx][7:0];
      tb_b8  = pattern_table[(idx + 1) % 8][7:0];
      tb_a16 = pattern_table[idx];
      tb_b16 = pattern_table[(idx + 1) % 8];

      #10;
      $fdisplay(fd_log, "8-bit  Test Case %0d: a = %6d, b = %6d, sum = %6d", idx + 1, tb_a8, tb_b8, tb_sum8);
      $fdisplay(fd_log, "16-bit Test Case %0d: a = %6d, b = %6d, sum = %6d", idx + 1, tb_a16, tb_b16, tb_sum16);
    end

    // 2. 추가 케이스: Large + Small
    apply_custom_case(8'hFE, 8'h01, 16'hFFFE, 16'h0001, "Large + Small");

    // 3. 추가 케이스: Near Max
    apply_custom_case(8'h7F, 8'h7E, 16'h7FFE, 16'h7FFE, "Near Max");

    // 4. 추가 케이스: Overflow Test
    apply_custom_case(8'hFF, 8'h01, 16'hFFFF, 16'h0001, "Overflow Test");

    $fdisplay(fd_log, "Test completed");
    $fclose(fd_log);
    $finish;
  end

endmodule
