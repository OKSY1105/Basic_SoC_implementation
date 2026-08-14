`timescale 1ns / 1ps
module testbench;
  //------------------------------------------
  // Global Clock & Reset
  //------------------------------------------
  reg clk;
  reg reset;
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz
  end
  
  initial begin
    reset = 1;
    #22 reset = 0; // 비동기 리셋 해제
  end

  initial begin
    $timeformat(-9, 0, "ns", 10); // -9: ns, 0: decimal place, "ns": unit, 10:minimum field width
  end
  

  //1. L1_P1 Parity------------------------------------------
  integer f1;
  wire parity_error; 
  reg  [7:0] p1_data_in;
  
  parity_checker u_parity_checker (
    .data_in      (  p1_data_in      ),
    .parity_bit   (  1'b1         ),
    .parity_error (  parity_error )
  );

  initial begin
    forever begin
      @(p1_data_in);
        $fdisplay(f1,"data_in = %b, parity_bit = %d, parity_error = %d ", p1_data_in, 1'b1, parity_error);
    end
  end
  initial begin
    f1 = $fopen("output_1.txt", "w");
    p1_data_in = 0;
    #5;
    repeat(255) #1 p1_data_in = p1_data_in + 8'd1;
    #5;
    $fclose(f1);
  end


  //2. L1_P6 FSM ------------------------------------------
    reg in;
    wire out;
    integer f2;  
    integer f2_flag;  
  integer f2_i;
    // Instantiate the FSM
    fsm u_fsm (
        .clk(clk),
        .reset(reset),
        .in(in),
        .out(out)
    );

    reg [9:0] in_sequence = 10'b0111101110; // 원하는 입력 시퀀스
    // Test stimulus
    initial begin
      f2_flag = 1;
      f2 = $fopen("output_2.txt", "w");
      in = 0;
      #32;
      for (f2_i = 0; f2_i < 10; f2_i = f2_i + 1) begin
          @(posedge clk);
          in <= in_sequence[f2_i];
      end

      #20;
      f2_flag = 0;
      $fclose(f2);  
    end

    // Checker and display
    reg [3:0] cycle_count = 0;
    always @(posedge clk) begin
        if(f2_flag) begin
          cycle_count <= cycle_count + 1;
          $fdisplay(f2,"Cycle %0d: in = %b, out = %b", cycle_count, in, out);
        end
    end

  //3. L1_P7 counter ------------------------------------------
    wire [7:0] out_decade;   
    integer f3;  
    integer f3_flag;  


  counter u_counter (
    .clk              (  clk          ),
    .areset           (  reset        ),
    .out_decade       (  out_decade   )   
  );

  initial begin
    f3_flag = 1;
    f3 = $fopen("output_3.txt", "w");
    #1100;
    f3_flag = 0;
    $fclose(f3);  
  end
  
  always @(posedge clk) begin
    if(f3_flag) begin
      $fdisplay(f3,"o_decade = %2h", out_decade);
    end
  end

  //4. L1_P8 bin2gray ------------------------------------------
    reg [3:0] binary_in;
    wire [3:0] gray_out;
    integer f4;  

    bin_2_gray #(.WIDTH(4)) u_bin_2_gray (
        .binary_in(binary_in),
        .gray_out(gray_out)
    );

    initial begin
        f4 = $fopen("output_4.txt", "w");
        $fmonitor(f4,"binary_in=%b gray_out=%b", binary_in, gray_out);
        binary_in = 4'b0000; #10;
        binary_in = 4'b0001; #10;
        binary_in = 4'b0010; #10;
        binary_in = 4'b0011; #10;
        binary_in = 4'b0100; #10;
        binary_in = 4'b0101; #10;
        binary_in = 4'b0110; #10;
        binary_in = 4'b0111; #10;
        binary_in = 4'b1000; #10;
        binary_in = 4'b1001; #10;
        binary_in = 4'b1010; #10;
        binary_in = 4'b1011; #10;
        binary_in = 4'b1100; #10;
        binary_in = 4'b1101; #10;
        binary_in = 4'b1110; #10;
        binary_in = 4'b1111; #10;
        $fclose(f4);  
    end

// 5. L1_P11 clock gating ===========================================================
    reg enable;
    reg [7:0] p11_data_in;
    wire [7:0] p11_data_out;
    integer f5;  
    integer f5_flag;  

    // 모듈 인스턴스화
    clock_gating u_clock_gating (
        .clk_in(clk),
        .rst_n(~reset),
        .enable(enable),
        .data_in(p11_data_in),
        .data_out(p11_data_out)
    );

    initial begin
        // 초기화
        f5_flag = 1;
        enable = 0;
        p11_data_in = 8'h00;
        f5 = $fopen("output_5.txt", "w");

        // 리셋 해제
        #22 ;

        // 테스트 1: enable이 0일 때
        #7 p11_data_in = 8'hAA;
        #20;

        // 테스트 2: enable을 1로 설정
        enable = 1;
        #20 p11_data_in = 8'h55;
        #20;

        // 테스트 3: enable을 다시 0으로 설정
        enable = 0;
        #20 p11_data_in = 8'hFF;
        #20;

        // 테스트 4: enable을 다시 1로 설정
        enable = 1;
        #20;

        // 시뮬레이션 종료
        f5_flag = 0;
        $fclose(f5);  
    end

    // 결과 모니터링
    always @(posedge clk) begin
        if(f5_flag) begin
          $fdisplay(f5,"Enable=%b, Data_in=%h, Data_out=%h", 
                   enable, p11_data_in, p11_data_out);
        end
    end


// 6. L1_P12 interrupt_ctrl ===========================================================
   parameter INT_COUNT = 8;
    reg [INT_COUNT-1:0] interrupt_requests;
    reg interrupt_ack;
    wire [INT_COUNT-1:0] interrupt_service;
    wire interrupt_active;
    integer f6;  
    integer f6_flag;  

    interrupt_ctrl #(
        .INT_COUNT(INT_COUNT)
    ) u_interrupt_ctrl (
        .clk(clk),
        .rst_n(~reset),
        .interrupt_requests(interrupt_requests),
        .interrupt_ack(interrupt_ack),
        .interrupt_service(interrupt_service),
        .interrupt_active(interrupt_active)
    );

    initial begin
        f6_flag = 1;
        f6 = $fopen("output_6.txt", "w");
        interrupt_requests = 0;
        interrupt_ack = 0;

        #22; 
        // 테스트 시나리오
        #10 interrupt_requests = 8'b00000001; // 낮은 우선순위 인터럽트
        #20 interrupt_requests = 8'b00000011; // 두 개의 인터럽트
        #20 interrupt_requests = 8'b10000011; // 높은 우선순위 인터럽트 추가
        #20 interrupt_ack = 1; // 첫 번째 인터럽트 처리 완료
        #10 interrupt_ack = 0;
        #20 interrupt_ack = 1; // 두 번째 인터럽트 처리 완료
        #10 interrupt_ack = 0;
        #20 interrupt_ack = 1; // 세 번째 인터럽트 처리 완료
        #10 interrupt_ack = 0;
        #10;
        f6_flag = 0;
        $fclose(f6);  
    end

    // 결과 모니터링
    always @(posedge clk) begin
        if(f6_flag) begin
          $fdisplay(f6,"Requests=%b, Active=%b, Service=%b", 
                    interrupt_requests, interrupt_active, interrupt_service);
        end
    end

// 7. L1_P20 msb_one_extractor ===========================================================
  // 입력과 출력 신호 정의
    reg [7:0] p20_data_in;
    wire [7:0] p20_data_out;
    integer f7;  

    // DUT (Device Under Test) 인스턴스화
    msb_one_extractor dut (
        .data_in(p20_data_in),
        .data_out(p20_data_out)
    );

    // 테스트 시나리오
    initial begin
        f7 = $fopen("output_7.txt", "w");
        // 테스트 케이스 1
        p20_data_in = 8'b01100001;
        #10;
        $fdisplay(f7,"Test Case 1: Input = %b, Output = %b", p20_data_in, p20_data_out);

        // 테스트 케이스 2
        p20_data_in = 8'b00100101;
        #10;
        $fdisplay(f7,"Test Case 2: Input = %b, Output = %b", p20_data_in, p20_data_out);

        // 테스트 케이스 3
        p20_data_in = 8'b10000000;
        #10;
        $fdisplay(f7,"Test Case 3: Input = %b, Output = %b", p20_data_in, p20_data_out);

        // 테스트 케이스 4
        p20_data_in = 8'b00000001;
        #10;
        $fdisplay(f7,"Test Case 4: Input = %b, Output = %b", p20_data_in, p20_data_out);

        // 테스트 케이스 5
        p20_data_in = 8'b00000000;
        #10;
        $fdisplay(f7,"Test Case 5: Input = %b, Output = %b", p20_data_in, p20_data_out);

        // 시뮬레이션 종료
        $fclose(f7);  
    end

// 8. L1_P21 edge_detector ===========================================================
    // 테스트 대상 모듈의 입출력 신호 정의
    reg signal;
    wire edge_detected;
    integer f8;  
    integer f8_flag;  

    // 테스트 대상 모듈 인스턴스화
    rising_edge_detector uut (
        .clk(clk),
        .signal(signal),
        .edge_detected(edge_detected)
    );

    // 테스트 시나리오
    initial begin
        f8_flag = 0;
        f8 = $fopen("output_8.txt", "w");
        signal = 0;
        #30;
        f8_flag = 1;
        // 테스트 케이스 1: 단일 상승 에지
        #10 signal = 1;
        #10 signal = 0;

        // 테스트 케이스 2: 연속된 1
        #20 signal = 1;
        #20 signal = 1;
        #10 signal = 0;

        // 테스트 케이스 3: 빠른 토글
        #11 signal = 1;
        #5  signal = 0;
        #5  signal = 1;
        #5  signal = 0;

        // 테스트 케이스 4: 긴 0 상태 후 상승
        #31 signal = 1;
        #20
        // 시뮬레이션 종료
        #10;
        f8_flag = 0;
        $fclose(f8);  
    end

    // 결과 모니터링
    always @(posedge clk) begin
        if(f8_flag) begin
          $fdisplay(f8,"Time=%6t, Signal=%b, Edge Detected=%b", $time, signal, edge_detected);
        end
    end

// 9. L1_P24 param_mem ===========================================================
    // 첫 번째 MEM (4-bit 주소, 8-bit 데이터)
    parameter MEM_N1 = 4;
    parameter MEM_DATA_WIDTH1 = 8;
    reg [MEM_N1-1:0] addr1;
    reg [MEM_DATA_WIDTH1-1:0] data_in1;
    reg write_enable1;
    wire [MEM_DATA_WIDTH1-1:0] data_out1;

    param_mem #(
        .N(MEM_N1),
        .DATA_WIDTH(MEM_DATA_WIDTH1)
    ) rom1 (
        .clk(clk),
        .addr(addr1),
        .data_in(data_in1),
        .write_enable(write_enable1),
        .data_out(data_out1)
    );

    integer f9;  
    integer f9_i;  
    integer f9_i_check;  

    // 테스트 시나리오
    initial begin
        f9 = $fopen("output_9.txt", "w");
        addr1 = 0;
        data_in1 = 0;
        write_enable1 = 0;
        #22;
        @(posedge clk);
        write_enable1 <= 1;
        for (f9_i = 0; f9_i < 2**MEM_N1; f9_i = f9_i + 1) begin
            @(posedge clk);
            addr1 <= f9_i;
            data_in1 <= f9_i * 2;
        end
            @(posedge clk);
        write_enable1 <= 0;

        for (f9_i = 0; f9_i < 2**MEM_N1; f9_i = f9_i + 1) begin
            addr1 <= f9_i;
            @(posedge clk);
        end

        @(posedge clk);
        $fclose(f9);  
    end

    initial begin
      wait (write_enable1 == 1);
      wait (write_enable1 == 0);
        $fdisplay(f9,"MEM1 (4-bit address, 8-bit data) Test:");
        for (f9_i_check = 0; f9_i_check < 2**MEM_N1; f9_i_check = f9_i_check + 1) begin
            @(posedge clk);
            #1;
            $fdisplay(f9,"Address: %d, Data: %d", f9_i_check, data_out1);
        end
    end

  //------------------------------------------
  // 시뮬레이션 종료
  //------------------------------------------
  initial begin
    #1200;
    $finish;
  end
endmodule