`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (DUT 포트와 연결)
  // ==========================================
  // Half Adder
  reg        tb_ha_a;
  reg        tb_ha_b;
  wire       tb_ha_s;
  wire       tb_ha_c;

  // Full Adder
  reg        tb_fa_a;
  reg        tb_fa_b;
  reg        tb_fa_cin;
  wire       tb_fa_s;
  wire       tb_fa_cout;

  // BCD Adder
  reg  [3:0] tb_bcd_a;
  reg  [3:0] tb_bcd_b;
  reg        tb_bcd_cin;
  wire [3:0] tb_bcd_sum;
  wire       tb_bcd_cout;

  integer    fd_log;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  adder u_adder (
    // Half Adder
    .i_half_a     ( tb_ha_a     ),
    .i_half_b     ( tb_ha_b     ),
    .o_half_sum   ( tb_ha_s     ),
    .o_half_carry ( tb_ha_c     ),

    // Full Adder
    .i_full_a     ( tb_fa_a     ),
    .i_full_b     ( tb_fa_b     ),
    .i_full_carry ( tb_fa_cin   ),
    .o_full_sum   ( tb_fa_s     ),
    .o_full_carry ( tb_fa_cout  ),

    // BCD Adder
    .i_bcd_a      ( tb_bcd_a    ),
    .i_bcd_b      ( tb_bcd_b    ),
    .i_bcd_carry  ( tb_bcd_cin  ),
    .o_bcd_sum    ( tb_bcd_sum  ),
    .o_bcd_carry  ( tb_bcd_cout )
  );

  // ==========================================
  // 정답 파일(answer.txt)과 100% 일치하는 테스트 시퀀스
  // ==========================================
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // --------------------------------------
    // 1. Half Adder Test
    // --------------------------------------
    $fdisplay(fd_log, "=== Half Adder Test ===");

    tb_ha_a = 1'b0; tb_ha_b = 1'b0; #10;
    $fdisplay(fd_log, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", tb_ha_a, tb_ha_b, tb_ha_s, tb_ha_c);

    tb_ha_a = 1'b0; tb_ha_b = 1'b1; #10;
    $fdisplay(fd_log, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", tb_ha_a, tb_ha_b, tb_ha_s, tb_ha_c);

    tb_ha_a = 1'b1; tb_ha_b = 1'b0; #10;
    $fdisplay(fd_log, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", tb_ha_a, tb_ha_b, tb_ha_s, tb_ha_c);

    tb_ha_a = 1'b1; tb_ha_b = 1'b1; #10;
    $fdisplay(fd_log, "i_half_a = %b, i_half_b = %b -> o_half_sum = %b, o_half_carry = %b", tb_ha_a, tb_ha_b, tb_ha_s, tb_ha_c);

    // --------------------------------------
    // 2. Full Adder Test
    // --------------------------------------
    $fdisplay(fd_log, "\n=== Full Adder Test ===");

    tb_fa_a = 1'b0; tb_fa_b = 1'b0; tb_fa_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b0; tb_fa_b = 1'b1; tb_fa_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b1; tb_fa_b = 1'b0; tb_fa_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b1; tb_fa_b = 1'b1; tb_fa_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b0; tb_fa_b = 1'b0; tb_fa_cin = 1'b1; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b0; tb_fa_b = 1'b1; tb_fa_cin = 1'b1; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b1; tb_fa_b = 1'b0; tb_fa_cin = 1'b1; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    tb_fa_a = 1'b1; tb_fa_b = 1'b1; tb_fa_cin = 1'b1; #10;
    $fdisplay(fd_log, "i_full_a = %b, i_full_b = %b, i_full_carry = %b -> o_full_sum = %b, o_full_carry = %b", tb_fa_a, tb_fa_b, tb_fa_cin, tb_fa_s, tb_fa_cout);

    // --------------------------------------
    // 3. BCD Adder Test
    // --------------------------------------
    $fdisplay(fd_log, "\n=== BCD Adder Test ===");

    tb_bcd_a = 4'd2; tb_bcd_b = 4'd3; tb_bcd_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_bcd_a = %2d, i_bcd_b = %2d, i_bcd_carry = %b -> o_bcd_sum = %2d, o_bcd_carry = %b", tb_bcd_a, tb_bcd_b, tb_bcd_cin, tb_bcd_sum, tb_bcd_cout);

    tb_bcd_a = 4'd5; tb_bcd_b = 4'd5; tb_bcd_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_bcd_a = %2d, i_bcd_b = %2d, i_bcd_carry = %b -> o_bcd_sum = %2d, o_bcd_carry = %b", tb_bcd_a, tb_bcd_b, tb_bcd_cin, tb_bcd_sum, tb_bcd_cout);

    tb_bcd_a = 4'd8; tb_bcd_b = 4'd7; tb_bcd_cin = 1'b0; #10;
    $fdisplay(fd_log, "i_bcd_a = %2d, i_bcd_b = %2d, i_bcd_carry = %b -> o_bcd_sum = %2d, o_bcd_carry = %b", tb_bcd_a, tb_bcd_b, tb_bcd_cin, tb_bcd_sum, tb_bcd_cout);

    tb_bcd_a = 4'd9; tb_bcd_b = 4'd9; tb_bcd_cin = 1'b1; #10;
    $fdisplay(fd_log, "i_bcd_a = %2d, i_bcd_b = %2d, i_bcd_carry = %b -> o_bcd_sum = %2d, o_bcd_carry = %b", tb_bcd_a, tb_bcd_b, tb_bcd_cin, tb_bcd_sum, tb_bcd_cout);

    $fclose(fd_log);
    $finish;
  end

endmodule
