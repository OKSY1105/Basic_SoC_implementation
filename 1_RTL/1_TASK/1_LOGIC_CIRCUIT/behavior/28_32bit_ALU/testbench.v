`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (tb_ Prefix 적용)
  // ==========================================
  reg  [31:0] tb_src_a;
  reg  [31:0] tb_src_b;
  reg  [3:0]  tb_alu_op;

  wire [31:0] tb_alu_res;
  wire        tb_zero_flag;
  wire        tb_ovf_flag;

  integer     fd_log;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  alu_32b dut_alu (
    .i_a        ( tb_src_a     ),
    .i_b        ( tb_src_b     ),
    .i_op       ( tb_alu_op    ),
    .o_result   ( tb_alu_res   ),
    .o_zero     ( tb_zero_flag ),
    .o_overflow ( tb_ovf_flag  )
  );

  // ==========================================
  // 결과 검증 및 파일 기록 태스크
  // ==========================================
  task check_and_log;
    input [3:0]  op_code;
    input [31:0] val_a, val_b, golden_val;
    begin
      #10; // 지연 시간 유지

      // 원본과 100% 일치하는 포맷으로 기록
      $fdisplay(fd_log, "Op: %b, A: %h, B: %h, Result: %h, Expected: %h, Zero: %b, Overflow: %b",
                op_code, $signed(val_a), $signed(val_b), $signed(tb_alu_res), $signed(golden_val), tb_zero_flag, tb_ovf_flag);

      if (tb_alu_res !== golden_val) begin
        $fdisplay(fd_log, "ERROR: Mismatch detected!");
      end

      $fflush(fd_log);
    end
  endtask

  // ==========================================
  // 테스트 자극 시퀀스
  // ==========================================
  initial begin
    fd_log = $fopen("output.txt", "w");
    if (!fd_log) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // TC 1: 덧셈
    tb_src_a = 32'd10; tb_src_b = 32'd20; tb_alu_op = 4'b0000;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'd30);

    // TC 2: 뺄셈
    tb_src_a = 32'd30; tb_src_b = 32'd15; tb_alu_op = 4'b0001;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'd15);

    // TC 3: AND
    tb_src_a = 32'hFF00FF00; tb_src_b = 32'h0F0F0F0F; tb_alu_op = 4'b0010;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'h0F000F00);

    // TC 4: OR
    tb_src_a = 32'hFF00FF00; tb_src_b = 32'h0F0F0F0F; tb_alu_op = 4'b0011;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'hFF0FFF0F);

    // TC 5: XOR
    tb_src_a = 32'hFF00FF00; tb_src_b = 32'h0F0F0F0F; tb_alu_op = 4'b0100;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'hF00FF00F);

    // TC 6: NOT
    tb_src_a = 32'hFF00FF00; tb_src_b = 32'h0F0F0F0F; tb_alu_op = 4'b0101;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'h00FF00FF);

    // TC 7: 논리 좌측 시프트 (SLL)
    tb_src_a = 32'h0000FFFF; tb_src_b = 32'd4; tb_alu_op = 4'b0110;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'h000FFFF0);

    // TC 8: 논리 우측 시프트 (SRL)
    tb_src_a = 32'hFF000000; tb_src_b = 32'd4; tb_alu_op = 4'b0111;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'h0FF00000);

    // TC 9: 산술 우측 시프트 (SRA)
    tb_src_a = 32'h80000000; tb_src_b = 32'd1; tb_alu_op = 4'b1000;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'hC0000000);

    // TC 10: 부호 있는 비교 (SLT)
    tb_src_a = -32'd10; tb_src_b = 32'd5; tb_alu_op = 4'b1001;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'd1);

    // TC 11: 부호 없는 비교 (SLTU)
    tb_src_a = 32'hFFFFFFFF; tb_src_b = 32'd1; tb_alu_op = 4'b1010;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'd0);

    // TC 12: 오버플로우 (덧셈)
    tb_src_a = 32'h7FFFFFFF; tb_src_b = 32'd1; tb_alu_op = 4'b0000;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'h80000000);

    // TC 13: 오버플로우 (뺄셈)
    tb_src_a = 32'h80000000; tb_src_b = 32'd1; tb_alu_op = 4'b0001;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'h7FFFFFFF);

    // TC 14: 제로 플래그
    tb_src_a = 32'd0; tb_src_b = 32'd0; tb_alu_op = 4'b0000;
    check_and_log(tb_alu_op, tb_src_a, tb_src_b, 32'd0);

    $fclose(fd_log);
    $finish;
  end

endmodule
