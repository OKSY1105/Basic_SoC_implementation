`timescale 1ns / 1ps

module testbench;

  // ==========================================
  // 신호 정의 (변수명 리팩토링)
  // ==========================================
  // MUX 2:1
  reg  [3:0]    tb_m2_0, tb_m2_1;
  reg           tb_m2_s;
  wire [3:0]    tb_m2_out;

  // MUX 9:1
  reg  [3:0]    tb_m9_0, tb_m9_1, tb_m9_2;
  reg  [3:0]    tb_m9_3, tb_m9_4, tb_m9_5;
  reg  [3:0]    tb_m9_6, tb_m9_7, tb_m9_8;
  reg  [3:0]    tb_m9_s;
  wire [3:0]    tb_m9_out;

  // MUX 256:1
  reg  [2047:0] tb_m256_in;
  reg  [7:0]    tb_m256_s;
  wire [7:0]    tb_m256_out;

  // DEMUX 1:2
  reg  [3:0]    tb_dm2_in;
  reg           tb_dm2_s;
  wire [3:0]    tb_dm2_out0, tb_dm2_out1;

  // DEMUX 1:9
  reg  [3:0]    tb_dm9_in;
  reg  [3:0]    tb_dm9_s;
  wire [3:0]    tb_dm9_out0, tb_dm9_out1, tb_dm9_out2;
  wire [3:0]    tb_dm9_out3, tb_dm9_out4, tb_dm9_out5;
  wire [3:0]    tb_dm9_out6, tb_dm9_out7, tb_dm9_out8;
  wire [35:0]   tb_dm9_bus;

  // DEMUX 1:256
  reg  [7:0]    tb_dm256_in;
  reg  [7:0]    tb_dm256_s;
  wire [2047:0] tb_dm256_out;

  integer       idx;
  integer       fd_out;

  // ==========================================
  // DUT 인스턴스화
  // ==========================================
  mux_demux u_mux_demux (
    .i_mux_2_to_1_0       ( tb_m2_0          ),
    .i_mux_2_to_1_1       ( tb_m2_1          ),
    .i_mux_2_to_1_sel     ( tb_m2_s          ),
    .o_mux_2_to_1         ( tb_m2_out        ),

    .i_mux_9_to_1_0       ( tb_m9_0          ),
    .i_mux_9_to_1_1       ( tb_m9_1          ),
    .i_mux_9_to_1_2       ( tb_m9_2          ),
    .i_mux_9_to_1_3       ( tb_m9_3          ),
    .i_mux_9_to_1_4       ( tb_m9_4          ),
    .i_mux_9_to_1_5       ( tb_m9_5          ),
    .i_mux_9_to_1_6       ( tb_m9_6          ),
    .i_mux_9_to_1_7       ( tb_m9_7          ),
    .i_mux_9_to_1_8       ( tb_m9_8          ),
    .i_mux_9_to_1_sel     ( tb_m9_s          ),
    .o_mux_9_to_1         ( tb_m9_out        ),

    .i_mux_256_to_1       ( tb_m256_in       ),
    .i_mux_256_to_1_sel   ( tb_m256_s        ),
    .o_mux_256_to_1       ( tb_m256_out      ),

    .i_demux_1_to_2       ( tb_dm2_in        ),
    .i_demux_1_to_2_sel   ( tb_dm2_s         ),
    .o_demux_1_to_2_0     ( tb_dm2_out0      ),
    .o_demux_1_to_2_1     ( tb_dm2_out1      ),

    .i_demux_1_to_9       ( tb_dm9_in        ),
    .i_demux_1_to_9_sel   ( tb_dm9_s         ),
    .o_demux_1_to_9_0     ( tb_dm9_out0      ),
    .o_demux_1_to_9_1     ( tb_dm9_out1      ),
    .o_demux_1_to_9_2     ( tb_dm9_out2      ),
    .o_demux_1_to_9_3     ( tb_dm9_out3      ),
    .o_demux_1_to_9_4     ( tb_dm9_out4      ),
    .o_demux_1_to_9_5     ( tb_dm9_out5      ),
    .o_demux_1_to_9_6     ( tb_dm9_out6      ),
    .o_demux_1_to_9_7     ( tb_dm9_out7      ),
    .o_demux_1_to_9_8     ( tb_dm9_out8      ),

    .i_demux_1_to_256     ( tb_dm256_in      ),
    .i_demux_1_to_256_sel ( tb_dm256_s       ),
    .o_demux_1_to_256     ( tb_dm256_out     )
  );

  assign tb_dm9_bus = {
    tb_dm9_out8, tb_dm9_out7, tb_dm9_out6,
    tb_dm9_out5, tb_dm9_out4, tb_dm9_out3,
    tb_dm9_out2, tb_dm9_out1, tb_dm9_out0
  };

  // ==========================================
  // 자극 인가 및 정밀 동기 파일 출력
  // ==========================================
  initial begin
    $timeformat(-9, 0, "ns", 6);

    fd_out = $fopen("output.txt", "w");
    if (!fd_out) begin
      $display("Error: Failed to open output.txt");
      $finish;
    end

    // answer.txt와 정확히 일치하는 CSV 헤더
    $fdisplay(fd_out, " Time,m2_sel,m2_o,m9_s,m9_o,m256_s,m256_o,dm2_s,dm2_o0,dm2_o1,dm9_s, dm9_outs,dm256_s,dm256_outs");

    // 1. 초기값 설정
    tb_m2_0 = 4'd3;
    tb_m2_1 = 4'd12;
    tb_m2_s = 1'b0;

    tb_m9_0 = 4'd1;
    tb_m9_1 = 4'd2;
    tb_m9_2 = 4'd3;
    tb_m9_3 = 4'd4;
    tb_m9_4 = 4'd5;
    tb_m9_5 = 4'd6;
    tb_m9_6 = 4'd7;
    tb_m9_7 = 4'd8;
    tb_m9_8 = 4'd9;
    tb_m9_s = 4'd0;

    for (idx = 0; idx < 256; idx = idx + 1) begin
      tb_m256_in[idx*8 +: 8] = idx[7:0];
    end
    tb_m256_s = 8'd0;

    tb_dm2_in   = 4'hF;
    tb_dm2_s    = 1'b0;

    tb_dm9_in   = 4'hF;
    tb_dm9_s    = 4'd0;

    tb_dm256_in  = 8'hFF;
    tb_dm256_s   = 8'd0;

    // 2. 0ns 시점 출력 (조합회로 전파 대기 #0)
    #0;
    $fdisplay(fd_out, "%t,     %h,   %h,   %h,   %h,    %h,    %h,    %h,     %h,     %h,    %h,%h,     %h,%h",
              $time,
              tb_m2_s, tb_m2_out,
              tb_m9_s, tb_m9_out,
              tb_m256_s, tb_m256_out,
              tb_dm2_s, tb_dm2_out0, tb_dm2_out1,
              tb_dm9_s, tb_dm9_bus,
              tb_dm256_s, tb_dm256_out);

    // 3. 10ns ~ 2550ns까지 255회 반복 출력 (10ns마다 정확히 1번씩 출력)
    repeat (255) begin
      #10;
      tb_m2_s    = tb_m2_s + 1'b1;
      tb_m9_s    = tb_m9_s + 4'd1;
      tb_m256_s  = tb_m256_s + 8'd1;
      tb_dm2_s   = tb_dm2_s + 1'b1;
      tb_dm9_s   = tb_dm9_s + 4'd1;
      tb_dm256_s = tb_dm256_s + 8'd1;
      #0; // 값 안정화 후 기록
      $fdisplay(fd_out, "%t,     %h,   %h,   %h,   %h,    %h,    %h,    %h,     %h,     %h,    %h,%h,     %h,%h",
                $time,
                tb_m2_s, tb_m2_out,
                tb_m9_s, tb_m9_out,
                tb_m256_s, tb_m256_out,
                tb_dm2_s, tb_dm2_out0, tb_dm2_out1,
                tb_dm9_s, tb_dm9_bus,
                tb_dm256_s, tb_dm256_out);
    end

    $fclose(fd_out);
    $finish;
  end

endmodule
