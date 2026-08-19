`timescale 1ns / 1ps

module testbench;

  //----------------------------------------------------------------------------
  // Global Clock & Async Reset Generator
  //----------------------------------------------------------------------------
  reg tb_clk;
  reg tb_rst;

  initial begin
    tb_clk = 1'b0;
    forever #5 tb_clk = ~tb_clk; // 100MHz 주파수
  end

  initial begin
    tb_rst = 1'b1;
    #22 tb_rst = 1'b0; // 22ns 비동기 리셋 해제
  end

  initial begin
    $timeformat(-9, 0, "ns", 10);
  end

  //----------------------------------------------------------------------------
  // 1. Parity Checker (output_1.txt)
  //----------------------------------------------------------------------------
  integer fd_p1;
  reg  [7:0] p1_stim_data;
  wire       w_parity_err;

  parity_checker u_parity_checker (
    .data_in      (p1_stim_data),
    .parity_bit   (1'b1),
    .parity_error (w_parity_err)
  );

  initial begin
    forever begin
      @(p1_stim_data);
      $fdisplay(fd_p1, "data_in = %b, parity_bit = %d, parity_error = %d ", p1_stim_data, 1'b1, w_parity_err);
    end
  end

  initial begin
    fd_p1 = $fopen("output_1.txt", "w");
    p1_stim_data = 8'h00;
    #5;
    repeat(255) #1 p1_stim_data = p1_stim_data + 8'd1;
    #5;
    $fclose(fd_p1);
  end

  //----------------------------------------------------------------------------
  // 2. FSM Sequence Detector (output_2.txt)
  //----------------------------------------------------------------------------
  reg        fsm_stim_in;
  wire       w_fsm_out;
  integer    fd_p2;
  integer    p2_active;
  integer    p2_step;
  reg  [3:0] p2_cycle_cnt;

  fsm u_fsm (
    .clk   (tb_clk),
    .reset (tb_rst),
    .in    (fsm_stim_in),
    .out   (w_fsm_out)
  );

  // 10비트 패턴: 0111101110
  reg [9:0] fsm_pattern;

  initial begin
    p2_active   = 1;
    p2_cycle_cnt = 4'd0;
    fsm_pattern = 10'b0111101110;
    fd_p2       = $fopen("output_2.txt", "w");
    fsm_stim_in = 1'b0;

    #32;
    for (p2_step = 0; p2_step < 10; p2_step = p2_step + 1) begin
      @(posedge tb_clk);
      fsm_stim_in <= fsm_pattern[p2_step];
    end

    #20;
    p2_active = 0;
    $fclose(fd_p2);
  end

  always @(posedge tb_clk) begin
    if (p2_active) begin
      p2_cycle_cnt <= p2_cycle_cnt + 1'b1;
      $fdisplay(fd_p2, "Cycle %0d: in = %b, out = %b", p2_cycle_cnt, fsm_stim_in, w_fsm_out);
    end
  end

  //----------------------------------------------------------------------------
  // 3. Decade Counter (output_3.txt)
  //----------------------------------------------------------------------------
  wire [7:0] w_decade_cnt;
  integer    fd_p3;
  integer    p3_active;

  counter u_counter (
    .clk        (tb_clk),
    .areset     (tb_rst),
    .out_decade (w_decade_cnt)
  );

  initial begin
    p3_active = 1;
    fd_p3     = $fopen("output_3.txt", "w");
    #1100;
    p3_active = 0;
    $fclose(fd_p3);
  end

  always @(posedge tb_clk) begin
    if (p3_active) begin
      $fdisplay(fd_p3, "o_decade = %2h", w_decade_cnt);
    end
  end

  //----------------------------------------------------------------------------
  // 4. Binary to Gray Converter (output_4.txt)
  //----------------------------------------------------------------------------
  reg  [3:0] bin_stim;
  wire [3:0] w_gray_code;
  integer    fd_p4;
  integer    p4_iter;

  bin_2_gray #(.WIDTH(4)) u_bin_2_gray (
    .binary_in (bin_stim),
    .gray_out  (w_gray_code)
  );

  initial begin
    fd_p4 = $fopen("output_4.txt", "w");
    $fmonitor(fd_p4, "binary_in=%b gray_out=%b", bin_stim, w_gray_code);
    
    for (p4_iter = 0; p4_iter < 16; p4_iter = p4_iter + 1) begin
      bin_stim = p4_iter[3:0];
      #10;
    end
    $fclose(fd_p4);
  end

  //----------------------------------------------------------------------------
  // 5. Clock Gating Unit (output_5.txt)
  //----------------------------------------------------------------------------
  reg        cg_enable;
  reg  [7:0] cg_stim_data;
  wire [7:0] w_cg_dout;
  integer    fd_p5;
  integer    p5_active;

  clock_gating u_clock_gating (
    .clk_in   (tb_clk),
    .rst_n    (~tb_rst),
    .enable   (cg_enable),
    .data_in  (cg_stim_data),
    .data_out (w_cg_dout)
  );

  initial begin
    p5_active    = 1;
    cg_enable    = 1'b0;
    cg_stim_data = 8'h00;
    fd_p5        = $fopen("output_5.txt", "w");

    #22;
    #7  cg_stim_data = 8'hAA;
    #20;

    cg_enable    = 1'b1;
    #20 cg_stim_data = 8'h55;
    #20;

    cg_enable    = 1'b0;
    #20 cg_stim_data = 8'hFF;
    #20;

    cg_enable    = 1'b1;
    #20;

    p5_active    = 0;
    $fclose(fd_p5);
  end

  always @(posedge tb_clk) begin
    if (p5_active) begin
      $fdisplay(fd_p5, "Enable=%b, Data_in=%h, Data_out=%h", cg_enable, cg_stim_data, w_cg_dout);
    end
  end

  //----------------------------------------------------------------------------
  // 6. Interrupt Controller (output_6.txt)
  //----------------------------------------------------------------------------
  parameter INT_COUNT = 8;
  reg  [INT_COUNT-1:0] irq_reqs;
  reg                  irq_ack;
  wire [INT_COUNT-1:0] w_irq_svc;
  wire                 w_irq_act;
  integer              fd_p6;
  integer              p6_active;

  interrupt_ctrl #(
    .INT_COUNT(INT_COUNT)
  ) u_interrupt_ctrl (
    .clk                (tb_clk),
    .rst_n              (~tb_rst),
    .interrupt_requests (irq_reqs),
    .interrupt_ack      (irq_ack),
    .interrupt_service  (w_irq_svc),
    .interrupt_active   (w_irq_act)
  );

  initial begin
    p6_active = 1;
    fd_p6     = $fopen("output_6.txt", "w");
    irq_reqs  = {INT_COUNT{1'b0}};
    irq_ack   = 1'b0;

    #22;
    #10 irq_reqs = 8'b00000001;
    #20 irq_reqs = 8'b00000011;
    #20 irq_reqs = 8'b10000011;
    #20 irq_ack  = 1'b1;
    #10 irq_ack  = 1'b0;
    #20 irq_ack  = 1'b1;
    #10 irq_ack  = 1'b0;
    #20 irq_ack  = 1'b1;
    #10 irq_ack  = 1'b0;
    #10;
    
    p6_active = 0;
    $fclose(fd_p6);
  end

  always @(posedge tb_clk) begin
    if (p6_active) begin
      $fdisplay(fd_p6, "Requests=%b, Active=%b, Service=%b", irq_reqs, w_irq_act, w_irq_svc);
    end
  end

  //----------------------------------------------------------------------------
  // 7. MSB One Extractor (output_7.txt)
  //----------------------------------------------------------------------------
  reg  [7:0] msb_stim_data;
  wire [7:0] w_msb_one_out;
  integer    fd_p7;

  msb_one_extractor dut (
    .data_in  (msb_stim_data),
    .data_out (w_msb_one_out)
  );

  task check_msb_pattern;
    input [7:0]     pattern;
    input integer   case_idx;
    begin
      msb_stim_data = pattern;
      #10;
      $fdisplay(fd_p7, "Test Case %0d: Input = %b, Output = %b", case_idx, msb_stim_data, w_msb_one_out);
    end
  endtask

  initial begin
    fd_p7 = $fopen("output_7.txt", "w");
    check_msb_pattern(8'b01100001, 1);
    check_msb_pattern(8'b00100101, 2);
    check_msb_pattern(8'b10000000, 3);
    check_msb_pattern(8'b00000001, 4);
    check_msb_pattern(8'b00000000, 5);
    $fclose(fd_p7);
  end

  //----------------------------------------------------------------------------
  // 8. Rising Edge Detector (output_8.txt)
  //----------------------------------------------------------------------------
  reg     edge_raw_sig;
  wire    w_edge_pulse;
  integer fd_p8;
  integer p8_active;

  rising_edge_detector uut (
    .clk           (tb_clk),
    .signal        (edge_raw_sig),
    .edge_detected (w_edge_pulse)
  );

  initial begin
    p8_active    = 0;
    fd_p8        = $fopen("output_8.txt", "w");
    edge_raw_sig = 1'b0;

    #30;
    p8_active = 1;

    #10 edge_raw_sig = 1'b1;
    #10 edge_raw_sig = 1'b0;

    #20 edge_raw_sig = 1'b1;
    #20 edge_raw_sig = 1'b1;
    #10 edge_raw_sig = 1'b0;

    #11 edge_raw_sig = 1'b1;
    #5  edge_raw_sig = 1'b0;
    #5  edge_raw_sig = 1'b1;
    #5  edge_raw_sig = 1'b0;

    #31 edge_raw_sig = 1'b1;
    #20;

    #10;
    p8_active = 0;
    $fclose(fd_p8);
  end

  always @(posedge tb_clk) begin
    if (p8_active) begin
      $fdisplay(fd_p8, "Time=%6t, Signal=%b, Edge Detected=%b", $time, edge_raw_sig, w_edge_pulse);
    end
  end

  //----------------------------------------------------------------------------
  // 9. Parameterized Memory (output_9.txt)
  //----------------------------------------------------------------------------
  parameter MEM_N1          = 4;
  parameter MEM_DATA_WIDTH1 = 8;

  reg  [MEM_N1-1:0]          mem_addr;
  reg  [MEM_DATA_WIDTH1-1:0] mem_wdata;
  reg                        mem_wr_en;
  wire [MEM_DATA_WIDTH1-1:0] w_mem_rdata;

  param_mem #(
    .N          (MEM_N1),
    .DATA_WIDTH (MEM_DATA_WIDTH1)
  ) rom1 (
    .clk          (tb_clk),
    .addr         (mem_addr),
    .data_in      (mem_wdata),
    .write_enable (mem_wr_en),
    .data_out     (w_mem_rdata)
  );

  integer fd_p9;
  integer p9_w_idx;
  integer p9_r_idx;
  integer p9_chk_idx;

  initial begin
    fd_p9     = $fopen("output_9.txt", "w");
    mem_addr  = {MEM_N1{1'b0}};
    mem_wdata = {MEM_DATA_WIDTH1{1'b0}};
    mem_wr_en = 1'b0;

    #22;
    @(posedge tb_clk);
    mem_wr_en <= 1'b1;

    for (p9_w_idx = 0; p9_w_idx < (1<<MEM_N1); p9_w_idx = p9_w_idx + 1) begin
      @(posedge tb_clk);
      mem_addr  <= p9_w_idx[MEM_N1-1:0];
      mem_wdata <= p9_w_idx * 2;
    end
    @(posedge tb_clk);
    mem_wr_en <= 1'b0;

    for (p9_r_idx = 0; p9_r_idx < (1<<MEM_N1); p9_r_idx = p9_r_idx + 1) begin
      mem_addr <= p9_r_idx[MEM_N1-1:0];
      @(posedge tb_clk);
    end

    @(posedge tb_clk);
    $fclose(fd_p9);
  end

  initial begin
    wait (mem_wr_en == 1'b1);
    wait (mem_wr_en == 1'b0);
    $fdisplay(fd_p9, "MEM1 (4-bit address, 8-bit data) Test:");
    for (p9_chk_idx = 0; p9_chk_idx < (1<<MEM_N1); p9_chk_idx = p9_chk_idx + 1) begin
      @(posedge tb_clk);
      #1;
      $fdisplay(fd_p9, "Address: %d, Data: %d", p9_chk_idx, w_mem_rdata);
    end
  end

  //----------------------------------------------------------------------------
  // Total Simulation Termination
  //----------------------------------------------------------------------------
  initial begin
    #1200;
    $finish;
  end

endmodule
