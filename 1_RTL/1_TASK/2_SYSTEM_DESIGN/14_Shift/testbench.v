`timescale 1ns / 1ps

module testbench;

  reg        tb_clk;
  reg        tb_load_en;
  reg  [3:0] tb_din;
  wire [3:0] tb_qout;

  integer    fd_log;

  // DUT 인스턴스화
  shift u_shift (
    .i_clk   ( tb_clk     ),
    .i_load  ( tb_load_en ),
    .i_input ( tb_din     ),
    .o_out   ( tb_qout    )
  );

  // 클록 생성 (10ns 주기)
  always #5 tb_clk = ~tb_clk;

  // 모니터링 블록 (q 뒤에 공백 1칸 포함: "q=%b ")
  initial begin
    fd_log = $fopen("output.txt", "w");
    while (1) begin
      @(posedge tb_clk);
      if (|tb_qout !== 1'b0 && |tb_qout !== 1'b1) begin
        $display("load = %d, d=%b", tb_load_en, tb_din);
        $fdisplay(fd_log, "load = %d, d=%b", tb_load_en, tb_din);
      end else begin
        $display("load = %d, d=%b, q=%b ", tb_load_en, tb_din, tb_qout);
        $fdisplay(fd_log, "load = %d, d=%b, q=%b ", tb_load_en, tb_din, tb_qout);
      end
    end
  end

  // 자극 인가 시퀀스 (정확히 17줄 생성)
  initial begin
    tb_clk     = 1'b0;
    tb_load_en = 1'b0;
    // tb_din은 미할당(x) 상태 유지

    @(posedge tb_clk); // Line 1: load = 0, d=xxxx
    tb_din     <= 4'b1010;
    tb_load_en <= 1'b1;

    @(posedge tb_clk); // Line 2: load = 1, d=1010
    tb_load_en <= 1'b0;

    // Line 3~8: 6회 시프트
    repeat (6) @(posedge tb_clk);

    tb_din     <= 4'b1111;
    tb_load_en <= 1'b1;

    @(posedge tb_clk); // Line 9: load = 1, d=1111, q=0000 
    tb_load_en <= 1'b0;

    // Line 10~15: 6회 시프트
    repeat (6) @(posedge tb_clk);

    // Line 16, 17 (2회 추가 대기)
    @(posedge tb_clk);
    @(posedge tb_clk);
    #5;

    $fclose(fd_log);
    $finish;
  end

endmodule
