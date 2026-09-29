`timescale 1ns / 1ps

`ifdef SV_STYLE
module testbench;

    // 파라미터 정의
    parameter MUX_WIDTH = 8;
    parameter MUX_N1    = 4;
    parameter MUX_N2    = 8;

    // 4:1 및 8:1 MUX 신호 선언
    reg  [MUX_WIDTH-1:0]        arr_in_4 [MUX_N1-1:0];
    reg  [$clog2(MUX_N1)-1:0]   sel_4;
    wire [MUX_WIDTH-1:0]        w_out_4;

    reg  [MUX_WIDTH-1:0]        arr_in_8 [MUX_N2-1:0];
    reg  [$clog2(MUX_N2)-1:0]   sel_8;
    wire [MUX_WIDTH-1:0]        w_out_8;

    // 4:1 MUX 인스턴스화
    param_mux #(
        .N(MUX_N1),
        .WIDTH(MUX_WIDTH)
    ) u_mux_4 (
        .i_inputs (arr_in_4),
        .i_select (sel_4),
        .o_out    (w_out_4)
    );

    // 8:1 MUX 인스턴스화
    param_mux #(
        .N(MUX_N2),
        .WIDTH(MUX_WIDTH)
    ) u_mux_8 (
        .i_inputs (arr_in_8),
        .i_select (sel_8),
        .o_out    (w_out_8)
    );

    // MEM 신호 선언
    parameter MEM_N1          = 4;
    parameter MEM_DATA_WIDTH1 = 8;
    reg                          tb_clk;
    reg  [MEM_N1-1:0]            mem1_addr;
    reg  [MEM_DATA_WIDTH1-1:0]   mem1_din;
    reg                          mem1_we;
    wire [MEM_DATA_WIDTH1-1:0]   mem1_dout;

    parameter MEM_N2          = 6;
    parameter MEM_DATA_WIDTH2 = 16;
    reg  [MEM_N2-1:0]            mem2_addr;
    reg  [MEM_DATA_WIDTH2-1:0]   mem2_din;
    reg                          mem2_we;
    wire [MEM_DATA_WIDTH2-1:0]   mem2_dout;

    // MEM 인스턴스화
    param_mem #(
        .N(MEM_N1),
        .DATA_WIDTH(MEM_DATA_WIDTH1)
    ) u_mem1 (
        .i_clk          (tb_clk),
        .i_addr         (mem1_addr),
        .i_data_in      (mem1_din),
        .i_write_enable (mem1_we),
        .o_data_out     (mem1_dout)
    );

    param_mem #(
        .N(MEM_N2),
        .DATA_WIDTH(MEM_DATA_WIDTH2)
    ) u_mem2 (
        .i_clk          (tb_clk),
        .i_addr         (mem2_addr),
        .i_data_in      (mem2_din),
        .i_write_enable (mem2_we),
        .o_data_out     (mem2_dout)
    );

    // 100MHz 클럭 생성 (5ns 반주기)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    integer idx;
    integer log_fd;

    // 메인 테스트 시퀀스
    initial begin
        log_fd = $fopen("output.txt", "w");
        mem1_addr = 0;
        mem2_addr = 0;
        mem1_din  = 0;
        mem2_din  = 0;
        mem1_we   = 0;
        mem2_we   = 0;

        // MUX 입력 초기화
        for (idx = 0; idx < MUX_N1; idx = idx + 1) begin
            arr_in_4[idx] = idx * 10 + 1;
        end

        for (idx = 0; idx < MUX_N2; idx = idx + 1) begin
            arr_in_8[idx] = idx * 20 + 5;
        end

        // 4:1 MUX 순차 테스트
        for (idx = 0; idx < MUX_N1; idx = idx + 1) begin
            sel_4 = idx;
            #10;
            $fdisplay(log_fd, "4:1 MUX - Select: %d, Output: %d", sel_4, w_out_4);
        end

        // 8:1 MUX 순차 테스트
        for (idx = 0; idx < MUX_N2; idx = idx + 1) begin
            sel_8 = idx;
            #10;
            $fdisplay(log_fd, "8:1 MUX - Select: %d, Output: %d", sel_8, w_out_8);
        end

        // MUX 난수 선택 테스트
        repeat(5) begin
            sel_4 = $random % MUX_N1;
            sel_8 = $random % MUX_N2;
            #10;
            $fdisplay(log_fd, "Random Test - 4:1 MUX Select: %d, Output: %d", sel_4, w_out_4);
            $fdisplay(log_fd, "Random Test - 8:1 MUX Select: %d, Output: %d", sel_8, w_out_8);
        end

        // MEM1 데이터 기록
        mem1_we = 1;
        for (idx = 0; idx < 2**MEM_N1; idx = idx + 1) begin
            @(posedge tb_clk);
            mem1_addr = idx;
            mem1_din  = idx * 2;
        end
        @(posedge tb_clk);
        mem1_we = 0;

        // MEM2 데이터 기록
        mem2_we = 1;
        for (idx = 0; idx < 2**MEM_N2; idx = idx + 1) begin
            @(posedge tb_clk);
            mem2_addr = idx;
            mem2_din  = idx * 3;
        end
        @(posedge tb_clk);
        mem2_we = 0;
        @(posedge tb_clk);

        // MEM1 읽기 검증
        $fdisplay(log_fd, "MEM1 (4-bit address, 8-bit data) Test:");
        for (idx = 0; idx < 2**MEM_N1; idx = idx + 1) begin
            @(posedge tb_clk);
            mem1_addr = idx;
            @(posedge tb_clk);
            $fdisplay(log_fd, "Address: %d, Data: %d", mem1_addr, mem1_dout);
        end

        // MEM2 읽기 검증
        $fdisplay(log_fd, "\nMEM2 (6-bit address, 16-bit data) Test:");
        for (idx = 0; idx < 2**MEM_N2; idx = idx + 1) begin
            @(posedge tb_clk);
            mem2_addr = idx;
            @(posedge tb_clk);
            $fdisplay(log_fd, "Address: %d, Data: %d", mem2_addr, mem2_dout);
        end

        // MEM 난수 주소 테스트
        $fdisplay(log_fd, "\nRandom Address Test:");
        repeat(5) begin
            @(posedge tb_clk);
            mem1_addr = $random % (2**MEM_N1);
            @(posedge tb_clk);
            mem2_addr = $random % (2**MEM_N2);
            @(posedge tb_clk);
            $fdisplay(log_fd, "MEM1 - Address: %d, Data: %d", mem1_addr, mem1_dout);
            @(posedge tb_clk);
            $fdisplay(log_fd, "MEM2 - Address: %d, Data: %d", mem2_addr, mem2_dout);
        end

        $fclose(log_fd);
        $finish;
    end

endmodule

`else
module testbench;

    // 파라미터 정의
    parameter MUX_WIDTH = 8;
    parameter MUX_N1    = 4;
    parameter MUX_N2    = 8;

    // 4:1 및 8:1 MUX 신호 선언
    reg  [MUX_N1*MUX_WIDTH-1:0] flat_in_4;
    reg  [MUX_WIDTH-1:0]        shadow_in_4 [MUX_N1-1:0];
    reg  [$clog2(MUX_N1)-1:0]   sel_4;
    wire [MUX_WIDTH-1:0]        w_out_4;

    reg  [MUX_N2*MUX_WIDTH-1:0] flat_in_8;
    reg  [MUX_WIDTH-1:0]        shadow_in_8 [MUX_N2-1:0];
    reg  [$clog2(MUX_N2)-1:0]   sel_8;
    wire [MUX_WIDTH-1:0]        w_out_8;

    // 4:1 MUX 인스턴스화 (RTL 포트명: .i_inputs, .i_select, .o_out)
    param_mux #(
        .N(MUX_N1),
        .WIDTH(MUX_WIDTH)
    ) u_mux_4 (
        .i_inputs (flat_in_4),
        .i_select (sel_4),
        .o_out    (w_out_4)
    );

    // 8:1 MUX 인스턴스화 (RTL 포트명: .i_inputs, .i_select, .o_out)
    param_mux #(
        .N(MUX_N2),
        .WIDTH(MUX_WIDTH)
    ) u_mux_8 (
        .i_inputs (flat_in_8),
        .i_select (sel_8),
        .o_out    (w_out_8)
    );

    // MEM 파라미터 및 신호 선언
    parameter MEM_N1          = 4;
    parameter MEM_DATA_WIDTH1 = 8;
    reg                          tb_clk;
    reg  [MEM_N1-1:0]            mem1_addr;
    reg  [MEM_DATA_WIDTH1-1:0]   mem1_din;
    reg                          mem1_we;
    wire [MEM_DATA_WIDTH1-1:0]   mem1_dout;

    parameter MEM_N2          = 6;
    parameter MEM_DATA_WIDTH2 = 16;
    reg  [MEM_N2-1:0]            mem2_addr;
    reg  [MEM_DATA_WIDTH2-1:0]   mem2_din;
    reg                          mem2_we;
    wire [MEM_DATA_WIDTH2-1:0]   mem2_dout;

    // MEM 인스턴스화 (RTL 포트명: .i_clk, .i_addr, .i_data_in, .i_write_enable, .o_data_out)
    param_mem #(
        .N(MEM_N1),
        .DATA_WIDTH(MEM_DATA_WIDTH1)
    ) u_mem1 (
        .i_clk          (tb_clk),
        .i_addr         (mem1_addr),
        .i_data_in      (mem1_din),
        .i_write_enable (mem1_we),
        .o_data_out     (mem1_dout)
    );

    param_mem #(
        .N(MEM_N2),
        .DATA_WIDTH(MEM_DATA_WIDTH2)
    ) u_mem2 (
        .i_clk          (tb_clk),
        .i_addr         (mem2_addr),
        .i_data_in      (mem2_din),
        .i_write_enable (mem2_we),
        .o_data_out     (mem2_dout)
    );

    // 100MHz 클럭 생성 (5ns 반주기)
    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk;

    integer idx;
    integer log_fd;

    // 메인 시뮬레이션 제어
    initial begin
        log_fd = $fopen("output.txt", "w");
        mem1_addr = 0;
        mem2_addr = 0;
        mem1_din  = 0;
        mem2_din  = 0;
        mem1_we   = 0;
        mem2_we   = 0;

        // 4:1 MUX 버스 초기화
        for (idx = 0; idx < MUX_N1; idx = idx + 1) begin
            flat_in_4[idx*MUX_WIDTH +: MUX_WIDTH] = idx * 10 + 1;
            shadow_in_4[idx]                      = flat_in_4[idx*MUX_WIDTH +: MUX_WIDTH];
        end

        // 8:1 MUX 버스 초기화
        for (idx = 0; idx < MUX_N2; idx = idx + 1) begin
            flat_in_8[idx*MUX_WIDTH +: MUX_WIDTH] = idx * 20 + 5;
            shadow_in_8[idx]                      = flat_in_8[idx*MUX_WIDTH +: MUX_WIDTH];
        end

        // 4:1 MUX 순차 테스트
        for (idx = 0; idx < MUX_N1; idx = idx + 1) begin
            sel_4 = idx;
            #10;
            $fdisplay(log_fd, "4:1 MUX - Select: %d, Output: %d", sel_4, w_out_4);
        end

        $fdisplay(log_fd, "");

        // 8:1 MUX 순차 테스트
        for (idx = 0; idx < MUX_N2; idx = idx + 1) begin
            sel_8 = idx;
            #10;
            $fdisplay(log_fd, "8:1 MUX - Select: %d, Output: %d", sel_8, w_out_8);
        end

        $fdisplay(log_fd, "");

        // MUX 난수 선택 테스트
        repeat(5) begin
            sel_4 = $random % MUX_N1;
            sel_8 = $random % MUX_N2;
            #10;
            $fdisplay(log_fd, "Random Test - 4:1 MUX Select: %d, Output: %d", sel_4, w_out_4);
            $fdisplay(log_fd, "Random Test - 8:1 MUX Select: %d, Output: %d", sel_8, w_out_8);
        end

        // MEM1 동기식 데이터 쓰기
        mem1_we <= 1'b1;
        for (idx = 0; idx < 2**MEM_N1; idx = idx + 1) begin
            @(posedge tb_clk);
            mem1_addr <= idx;
            mem1_din  <= idx * 2;
        end
        @(posedge tb_clk);
        mem1_we <= 1'b0;

        // MEM2 동기식 데이터 쓰기
        mem2_we = 1'b1;
        for (idx = 0; idx < 2**MEM_N2; idx = idx + 1) begin
            @(posedge tb_clk);
            mem2_addr <= idx;
            mem2_din  <= idx * 3;
        end
        @(posedge tb_clk);
        mem2_we <= 1'b0;
        @(posedge tb_clk);

        // MEM1 읽기 검증
        $fdisplay(log_fd, "\nMEM1 (4-bit address, 8-bit data) Test:");
        for (idx = 0; idx < 2**MEM_N1; idx = idx + 1) begin
            mem1_addr <= idx;
            @(posedge tb_clk);
            #1;
            $fdisplay(log_fd, "Address: %d, Data: %d", mem1_addr, mem1_dout);
        end

        // MEM2 읽기 검증
        $fdisplay(log_fd, "\nMEM2 (6-bit address, 16-bit data) Test:");
        for (idx = 0; idx < 2**MEM_N2; idx = idx + 1) begin
            mem2_addr <= idx;
            @(posedge tb_clk);
            #1;
            $fdisplay(log_fd, "Address: %d, Data: %d", mem2_addr, mem2_dout);
        end

        // MEM 난수 주소 테스트
        $fdisplay(log_fd, "\nRandom Address Test:");
        repeat(5) begin
            mem1_addr <= $random % (2**MEM_N1);
            mem2_addr <= $random % (2**MEM_N2);
            @(posedge tb_clk);
            #1;
            $fdisplay(log_fd, "MEM1 - Address: %d, Data: %3d", mem1_addr, mem1_dout);
            $fdisplay(log_fd, "MEM2 - Address: %d, Data: %3d", mem2_addr, mem2_dout);
        end

        @(posedge tb_clk);
        $fclose(log_fd);
        $finish;
    end

endmodule
`endif
