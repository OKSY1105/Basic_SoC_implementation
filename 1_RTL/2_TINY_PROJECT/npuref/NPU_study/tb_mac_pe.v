`timescale 1ns/1ps

module tb_mac_pe;

  localparam DATA_W   = 8;
  localparam ACC_W    = 2*DATA_W;
  localparam SIM_TIME = 2000;

  reg                  clk;
  reg                  rst_n;
  reg                  clr;
  reg                  en;
  reg  [DATA_W-1:0]    a;
  reg  [DATA_W-1:0]    b;
  wire [ACC_W-1:0]     mul;
  wire [ACC_W-1:0]     acc_sum;

  mac_pe #(
    .DATA_W (DATA_W),
    .ACC_W  (ACC_W)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .clr     (clr),
    .en      (en),
    .a       (a),
    .b       (b),
    .mul     (mul),
    .acc_sum (acc_sum)
  );

  //==========================================================
  // Clock / Reset
  //==========================================================
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 100MHz
  end

  initial begin
    rst_n = 1'b0;
    clr   = 1'b0;
    en    = 1'b0;
    a     = 0;
    b     = 0;

    #30;
    rst_n = 1'b1;
  end

  //==========================================================
  // Reference Model & Checker (Watchpoint)
  //==========================================================
  wire [ACC_W-1:0] ref_mul;
  reg  [ACC_W-1:0] ref_sum;

  integer cycles_checked;
  integer err_mul_cnt;
  integer err_acc_cnt;

  // ref model
  assign ref_mul = a * b;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ref_sum <= 0;
    end else begin
      if (clr) begin
        ref_sum <= 0;
      end else if (en) begin
        ref_sum <= ref_sum + ref_mul;
      end
    end
  end

  // Checker
  always @(posedge clk) begin
    if (!rst_n) begin
      cycles_checked <= 0;
      err_mul_cnt    <= 0;
      err_acc_cnt    <= 0;
    end else begin
      cycles_checked = cycles_checked + 1;

      // WP1: mul
      if (mul !== ref_mul) begin
        err_mul_cnt = err_mul_cnt + 1;
        $display("ERROR! WP1 MUL mismatch: dut=%0d, ref=%0d, time=%0d ns",
                 mul, ref_mul, $time);
      end else begin
        $display("PASS!  WP1 MUL match   : dut=%0d, ref=%0d, time=%0d ns",
                 mul, ref_mul, $time);
      end

      // WP2: acc_sum
      if (acc_sum !== ref_sum) begin
        err_acc_cnt = err_acc_cnt + 1;
        $display("ERROR! WP2 ACC_SUM mismatch: dut=%0d, ref=%0d, time=%0d ns",
                 acc_sum, ref_sum, $time);
      end else begin
        $display("PASS!  WP2 ACC_SUM match   : dut=%0d, ref=%0d, time=%0d ns",
                 acc_sum, ref_sum, $time);
      end
    end
  end

  //==========================================================
  // Time-based Random Stimulus
  //==========================================================
  initial begin
    @(posedge rst_n);
    @(posedge clk);

    $display("[TB] Time-based Random Stress START, duration = %0d ns", SIM_TIME);

    fork
      // Thread 1: Random Stimulus
      begin : STIM_LOOP
        forever begin
          // operand
          a = {$random} % (1<<DATA_W);       // 0 to 255
          b = {$random} % (1<<DATA_W);

          // en
          en = {$random} % 2;

          // clr (5%)
          if (({$random} % 100) < 5) begin
            clr = 1'b1;
          end else begin
            clr = 1'b0;
          end

          @(posedge clk);
        end
      end

      // Thread 2: Timer
      begin : TIMER
        #SIM_TIME;
        disable STIM_LOOP;
      end
    join

    // idle
    en  = 1'b0;
    clr = 1'b0;
    a   = 0;
    b   = 0;
    repeat (5) @(posedge clk);

    //========================================================
    // Summary
    //========================================================
    $display("==================================================");
    $display("[TB] Simulation Summary");
    $display("  Simulation time    : %0d ns", SIM_TIME);
    $display("  Cycles checked     : %0d",    cycles_checked);
    $display("  MUL mismatches     : %0d",    err_mul_cnt);
    $display("  ACC_SUM mismatches : %0d",    err_acc_cnt);
    if (err_mul_cnt == 0 && err_acc_cnt == 0) begin
      $display("  RESULT             : PASS");
    end else begin
      $display("  RESULT             : FAIL");
    end
    $display("==================================================");

    $finish;
  end

endmodule
