`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (tb_ Prefix 적용)
  // ==========================================
  reg         tb_clk;
  reg         tb_arst;
  reg  [3:0]  tb_d_bit;
  reg  [31:0] tb_d_byte;
  reg         tb_load_cmd;
  reg         tb_shift_en;

  wire [3:0]         tb_out_bit_r_lsh;
  wire [3:0]         tb_out_bit_l_lsh;
  wire [31:0]        tb_out_byte_r_lsh;
  wire [31:0]        tb_out_byte_l_lsh;
  wire signed [3:0]  tb_out_bit_r_ash;
  wire signed [31:0] tb_out_byte_r_ash;
  wire [3:0]         tb_out_bit_r_rot;
  wire [3:0]         tb_out_bit_l_rot;
  wire [31:0]        tb_out_byte_r_rot;
  wire [31:0]        tb_out_byte_l_rot;

  integer fd_csv;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  shift u_shift (
    .i_clk                         ( tb_clk               ),
    .i_areset                      ( tb_arst              ),
    .i_bit_data                    ( tb_d_bit             ),
    .i_byte_data                   ( tb_d_byte            ),
    .i_load                        ( tb_load_cmd          ),
    .i_en                          ( tb_shift_en          ),
    .o_out_bit_r_logical_shift     ( tb_out_bit_r_lsh     ),
    .o_out_bit_l_logical_shift     ( tb_out_bit_l_lsh     ),
    .o_out_byte_r_logical_shift    ( tb_out_byte_r_lsh    ),
    .o_out_byte_l_logical_shift    ( tb_out_byte_l_lsh    ),
    .o_out_bit_r_arithmetic_shift  ( tb_out_bit_r_ash     ),
    .o_out_byte_r_arithmetic_shift ( tb_out_byte_r_ash    ),
    .o_out_bit_r_rotate            ( tb_out_bit_r_rot     ),
    .o_out_bit_l_rotate            ( tb_out_bit_l_rot     ),
    .o_out_byte_r_rotate           ( tb_out_byte_r_rot    ),
    .o_out_byte_l_rotate           ( tb_out_byte_l_rot    )
  );

  // ==========================================
  // 100MHz 클록 생성 (주기 10ns)
  // ==========================================
  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk;
  end

  // ==========================================
  // 비동기 리셋 펄스 인가
  // ==========================================
  initial begin
    tb_arst = 1'b0;
    #4 tb_arst = 1'b1;
    #4 tb_arst = 1'b0;
  end

  // ==========================================
  // 자극 인가 시퀀스
  // ==========================================
  initial begin
    tb_d_bit    = 4'b0000;
    tb_d_byte   = 32'h00000000;
    tb_load_cmd = 1'b0;
    tb_shift_en = 1'b0;

    @(posedge tb_clk) #1 begin
      tb_load_cmd = 1'b1;
      tb_shift_en = 1'b0;
      tb_d_bit    = 4'b1101;
      tb_d_byte   = 32'hA5A500A5;
    end

    @(posedge tb_clk) #1 begin
      tb_load_cmd = 1'b0;
    end

    @(posedge tb_clk) #1 begin
      tb_shift_en = 1'b1;
    end
  end

  // ==========================================
  // 파일 로깅 제어
  // ==========================================
  initial begin
    $timeformat(-9, 0, "ns", 4);

    fd_csv = $fopen("output.txt", "w");
    if (!fd_csv) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // 원본과 100% 동일한 헤더 기록
    $fwrite(fd_csv, "Time, arst, load, en, bt_data, by_data, obt_rl_sh, obt_ll_sh, oby_rl_sh, oby_ll_sh, obt_ra_sh, oby_ra_sh, obt_r_ro, obt_l_ro, oby_r_ro, oby_l_ro\n");

    repeat (9) @(posedge tb_clk);

    #10;
    $fclose(fd_csv);
    $finish;
  end

  // ==========================================
  // 사이클 단위 CSV 파일 기록
  // ==========================================
  always @(posedge tb_clk) begin
    $fwrite(fd_csv, "%t,    %b,    %b,  %b,    %b, %h,      %b,      %b,  %h,  %h,      %b,  %h,     %b,     %b, %h, %h\n",
            $time, tb_arst, tb_load_cmd, tb_shift_en, tb_d_bit, tb_d_byte,
            tb_out_bit_r_lsh, tb_out_bit_l_lsh, tb_out_byte_r_lsh, tb_out_byte_l_lsh,
            tb_out_bit_r_ash, tb_out_byte_r_ash,
            tb_out_bit_r_rot, tb_out_bit_l_rot, tb_out_byte_r_rot, tb_out_byte_l_rot);
  end

endmodule
