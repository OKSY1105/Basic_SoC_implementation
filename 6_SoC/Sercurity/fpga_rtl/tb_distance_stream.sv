`timescale 1ns/1ps
// Regression harness for the corrected project RTL in stage/fpga_rtl/.
// Time divisors are reduced; this checks functionality, not board timing.
module tb_distance_review;
  localparam integer CPB = 8;
  localparam integer REPORT_CYCLES = 200000;
  reg clk = 0;
  always #10 clk = ~clk;
  reg [3:0] sw = 0;
  reg sonar_echo = 0;
  reg echo_enabled = 1;
  reg echo_stuck_high = 0;
  integer target_cm = 23;
  wire sonar_trig, uart_tx;
  security_top #(
    .CLKS_PER_US(1), .CLKS_PER_2MS(40), .CLKS_PER_50MS(10000),
    .CLKS_PER_1S(REPORT_CYCLES), .DEBOUNCE_CYCLES(4), .CLKS_PER_BIT(CPB)
  ) dut (
    .clk(clk), .pb_key(2'b00), .sw(sw), .touch_key(4'b0000),
    .sonar_echo(sonar_echo), .sonar_trig(sonar_trig),
    .uart_rx(1'b1), .uart_tx(uart_tx)
  );

  // Echo stimulus represents a valid measurement, including synchronizer margin.
  integer pulse_cycles;
  initial forever begin
    @(negedge sonar_trig);
    if (echo_enabled) begin
      pulse_cycles = target_cm * 58 + 2;
      repeat (10) @(negedge clk);
      sonar_echo = 1;
      if (echo_stuck_high) wait (!echo_stuck_high);
      else repeat (pulse_cycles) @(negedge clk);
      sonar_echo = 0;
    end
  end

  task automatic receive_byte(output reg [7:0] value);
    integer bit_index;
    begin
      @(negedge uart_tx);
      #(20 * CPB + 10 * CPB);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        value[bit_index] = uart_tx;
        #(20 * CPB);
      end
      if (uart_tx !== 1'b1) begin
        $display("HARNESS_ERROR bad UART stop bit");
        $fatal(1);
      end
    end
  endtask

  integer distance_frames = 0;
  integer sonar_errors = 0;
  integer range_errors = 0;
  integer crc_errors = 0;
  integer last_distance = -1;
  integer parser_state = 0;
  integer payload_index = 0;
  reg [7:0] rx_byte, frame_type, frame_len, checksum;
  reg [223:0] payload;
  initial forever begin
    receive_byte(rx_byte);
    case (parser_state)
      0: if (rx_byte == 8'haa) parser_state = 1;
      1: begin frame_type = rx_byte; checksum = rx_byte; parser_state = 2; end
      2: begin
        frame_len = rx_byte; checksum = checksum ^ rx_byte;
        payload = 0; payload_index = 0;
        parser_state = (rx_byte == 0) ? 4 : 3;
      end
      3: begin
        payload = (payload << 8) | rx_byte;
        checksum = checksum ^ rx_byte;
        payload_index = payload_index + 1;
        if (payload_index == frame_len) parser_state = 4;
      end
      4: begin
        if (checksum !== rx_byte) crc_errors = crc_errors + 1;
        else if (frame_type == 1 && frame_len == 13 && payload[103:32] == "Distance:") begin
          distance_frames = distance_frames + 1;
          last_distance = (payload[31:24]-48)*1000 + (payload[23:16]-48)*100
                        + (payload[15:8]-48)*10 + (payload[7:0]-48);
          $display("UART sw=%04b avg_cm=%0d alert=%b payload=%s", sw,
                   dut.distance_cm, dut.alert_flag, payload[103:0]);
        end else if (frame_type == 1 && frame_len == 9 && payload[71:0] == "ERR:SONAR") begin
          sonar_errors = sonar_errors + 1;
        end else if (frame_type == 1 && frame_len == 9 && payload[71:0] == "ERR:RANGE") begin
          range_errors = range_errors + 1;
        end
        parser_state = 0;
      end
    endcase
  end

  integer match_count = 0;
  integer mismatches = 0;
  task automatic check_stream(input [3:0] mask, input integer cm);
    integer before_count, expected_value, received;
    begin
      @(negedge clk);
      sw = mask; target_cm = cm;
      // Six measurement slots settle the five-sample moving average.
      repeat (70000) @(negedge clk);
      if (dut.distance_cm !== cm) begin
        $display("HARNESS_ERROR target=%0d actual_avg=%0d", cm, dut.distance_cm);
        $fatal(1);
      end
      before_count = distance_frames;
      repeat (2*REPORT_CYCLES + 10000) @(negedge clk);
      received = distance_frames - before_count;
      expected_value = (cm >= 100) ? 0 : cm;
      if (received >= 2 && last_distance == expected_value) begin
        match_count = match_count + 1;
        $display("MATCH sw=%04b cm=%0d frames=%0d last=%0d", mask, cm, received, last_distance);
      end else begin
        mismatches = mismatches + 1;
        $display("REQUIREMENT_MISMATCH sw=%04b cm=%0d frames=%0d last=%0d expected=%0d",
                 mask, cm, received, last_distance, expected_value);
      end
    end
  endtask

  integer before_timeout_frames, before_errors;
  initial begin
    repeat (30) @(negedge clk);
    check_stream(4'b0000, 23);
    check_stream(4'b0001, 23);
    check_stream(4'b0010, 23);
    check_stream(4'b0100, 23);
    check_stream(4'b1000, 23); // Includes latched alarm state.
    check_stream(4'b0001, 99);
    check_stream(4'b0001, 100);
    check_stream(4'b0001, 101);
    check_stream(4'b0001, 150);
    check_stream(4'b0000, 150);
    check_stream(4'b0001, 23);
    echo_enabled = 0;
    repeat (70000) @(negedge clk);
    before_timeout_frames = distance_frames;
    before_errors = sonar_errors;
    repeat (2*REPORT_CYCLES + 10000) @(negedge clk);
    $display("NO_ECHO avg_cm=%0d distance_frames=%0d last_distance=%0d sonar_errors=%0d",
             dut.distance_cm, distance_frames-before_timeout_frames, last_distance,
             sonar_errors-before_errors);
    if (dut.distance_cm !== 100 || last_distance != 0 ||
        distance_frames-before_timeout_frames < 2 || sonar_errors == before_errors)
      $fatal(1, "Missing-echo handling failed");
    echo_enabled = 1;
    check_stream(4'b0000, 23);
    echo_stuck_high = 1;
    @(posedge dut.err_range);
    repeat (10) @(negedge clk);
    before_timeout_frames = distance_frames;
    before_errors = range_errors;
    repeat (2*REPORT_CYCLES + 10000) @(negedge clk);
    $display("STUCK_ECHO avg_cm=%0d distance_frames=%0d last_distance=%0d range_errors=%0d",
             dut.distance_cm, distance_frames-before_timeout_frames, last_distance,
             range_errors-before_errors);
    if (dut.distance_cm !== 100 || last_distance != 0 ||
        distance_frames-before_timeout_frames < 2 || range_errors == before_errors)
      $fatal(1, "Echo range-timeout handling failed");
    echo_stuck_high = 0;
    check_stream(4'b0000, 23);
    if (crc_errors != 0) $fatal(1, "UART CRC errors=%0d", crc_errors);
    if (mismatches != 0) $fatal(1, "Distance streaming requirement mismatch");
    $display("REVIEW_COMPLETE matches=%0d mismatches=%0d crc_errors=%0d", match_count, mismatches, crc_errors);
    $display("UART_DISTANCE_REGRESSION_PASS");
    $finish;
  end

  initial begin
    #300000000;
    $fatal(1, "Review harness timed out");
  end
endmodule
