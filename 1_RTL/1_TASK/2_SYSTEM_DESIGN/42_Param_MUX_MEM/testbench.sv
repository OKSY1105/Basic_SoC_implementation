`timescale 1ns / 1ps

`ifdef SV_STYLE
module testbench;

 
    // 파라미터 정의
    parameter MUX_WIDTH = 8;
    parameter MUX_N1 = 4;
    parameter MUX_N2 = 8;

    // 4:1 멀티플렉서를 위한 신호
    reg [MUX_WIDTH-1:0] inputs_4 [MUX_N1-1:0];
    reg [$clog2(MUX_N1)-1:0] select_4;
    wire [MUX_WIDTH-1:0] out_4;

    // 8:1 멀티플렉서를 위한 신호
    reg [MUX_WIDTH-1:0] inputs_8 [MUX_N2-1:0];
    reg [$clog2(MUX_N2)-1:0] select_8;
    wire [MUX_WIDTH-1:0] out_8;

    // 4:1 멀티플렉서 인스턴스화
    param_mux #(
        .N(MUX_N1),
        .WIDTH(MUX_WIDTH)
    ) mux_4 (
        .inputs(inputs_4),
        .select(select_4),
        .out(out_4)
    );

    // 8:1 멀티플렉서 인스턴스화
    param_mux #(
        .N(MUX_N2),
        .WIDTH(MUX_WIDTH)
    ) mux_8 (
        .inputs(inputs_8),
        .select(select_8),
        .out(out_8)
    );
    // 첫 번째 MEM (4-bit 주소, 8-bit 데이터)
    parameter MEM_N1 = 4;
    parameter MEM_DATA_WIDTH1 = 8;
    reg clk;
    reg [MEM_N1-1:0] addr1;
    reg [MEM_DATA_WIDTH1-1:0] data_in1;
    reg write_enable1;
    wire [MEM_DATA_WIDTH1-1:0] data_out1;

    // 두 번째 MEM (6-bit 주소, 16-bit 데이터)
    parameter MEM_N2 = 6;
    parameter MEM_DATA_WIDTH2 = 16;
    reg [MEM_N2-1:0] addr2;
    reg [MEM_DATA_WIDTH2-1:0] data_in2;
    reg write_enable2;
    wire [MEM_DATA_WIDTH2-1:0] data_out2;

    // MEM 모듈 인스턴스화
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

    param_mem #(
        .N(MEM_N2),
        .DATA_WIDTH(MEM_DATA_WIDTH2)
    ) rom2 (
        .clk(clk),
        .addr(addr2),
        .data_in(data_in2),
        .write_enable(write_enable2),
        .data_out(data_out2)
    );

    // 클럭 생성
    always #5 clk = ~clk;
    integer i;
    integer file;  

    // 테스트 시나리오
    initial begin
        file = $fopen("output.txt", "w");
        clk = 0;
        addr1 = 0;
        addr2 = 0;
        data_in1 = 0;
        data_in2 = 0;
        write_enable1 = 0;
        write_enable2 = 0;
        // 4:1 멀티플렉서 입력 초기화
        for (i = 0; i < MUX_N1; i = i + 1) begin
            inputs_4[i] = i * 10 + 1;  // 1, 11, 21, 31
        end

        // 8:1 멀티플렉서 입력 초기화
        for (i = 0; i < MUX_N2; i = i + 1) begin
            inputs_8[i] = i * 20 + 5;  // 5, 25, 45, 65, 85, 105, 125, 145
        end

        // 4:1 멀티플렉서 테스트
        for (i = 0; i < MUX_N1; i = i + 1) begin
            select_4 = i;
            #10;
            $fdisplay(file,"4:1 MUX - Select: %d, Output: %d", select_4, out_4);
        end

        // 8:1 멀티플렉서 테스트
        for (i = 0; i < MUX_N2; i = i + 1) begin
            select_8 = i;
            #10;
            $fdisplay(file,"8:1 MUX - Select: %d, Output: %d", select_8, out_8);
        end

        // 추가 테스트: 무작위 선택
        repeat(5) begin
            select_4 = $random % MUX_N1;
            select_8 = $random % MUX_N2;
            #10;
            $fdisplay(file,"Random Test - 4:1 MUX Select: %d, Output: %d", select_4, out_4);
            $fdisplay(file,"Random Test - 8:1 MUX Select: %d, Output: %d", select_8, out_8);
        end

      
        write_enable1 = 1;
        for (i = 0; i < 2**MEM_N1; i = i + 1) begin
            @(posedge clk);
            addr1 = i;
            data_in1 = i * 2;
        end
            @(posedge clk);
        write_enable1 = 0;

        write_enable2 = 1;
        for (i = 0; i < 2**MEM_N2; i = i + 1) begin
            @(posedge clk);
            addr2 = i;
            data_in2 = i * 3;
        end
            @(posedge clk);
        write_enable2 = 0;
            @(posedge clk);
        $fdisplay(file,"MEM1 (4-bit address, 8-bit data) Test:");
        for (i = 0; i < 2**MEM_N1; i = i + 1) begin
            @(posedge clk);
            addr1 = i;
            @(posedge clk);
            $fdisplay(file,"Address: %d, Data: %d", addr1, data_out1);
        end

        $fdisplay(file,"\nMEM2 (6-bit address, 16-bit data) Test:");
        for (i = 0; i < 2**MEM_N2; i = i + 1) begin
            @(posedge clk);
            addr2 = i;
            @(posedge clk);
            $fdisplay(file,"Address: %d, Data: %d", addr2, data_out2);
        end

        // 무작위 주소 테스트
        $fdisplay(file,"\nRandom Address Test:");
        repeat(5) begin
            @(posedge clk);
            addr1 = $random % (2**MEM_N1);
            @(posedge clk);
            addr2 = $random % (2**MEM_N2);
            @(posedge clk);
            $fdisplay(file,"MEM1 - Address: %d, Data: %d", addr1, data_out1);
            @(posedge clk);
            $fdisplay(file,"MEM2 - Address: %d, Data: %d", addr2, data_out2);
        end
        $fclose(file);  
        $finish;
    end

endmodule

`else
module testbench;

    // 파라미터 정의
    parameter MUX_WIDTH = 8;
    parameter MUX_N1 = 4;
    parameter MUX_N2 = 8;

    // 4:1 멀티플렉서를 위한 신호
    reg [MUX_N1*MUX_WIDTH-1:0] inputs_4;       // 1차원 배열로 펼친 입력
    reg [MUX_WIDTH-1:0] input_4[MUX_N1-1:0];       
    reg [$clog2(MUX_N1)-1:0] select_4;     // 선택 신호
    wire [MUX_WIDTH-1:0] out_4;            // 출력 신호

    // 8:1 멀티플렉서를 위한 신호
    reg [MUX_N2*MUX_WIDTH-1:0] inputs_8;       // 1차원 배열로 펼친 입력
    reg [MUX_WIDTH-1:0] input_8[MUX_N2-1:0];       
    reg [$clog2(MUX_N2)-1:0] select_8;     // 선택 신호
    wire [MUX_WIDTH-1:0] out_8;            // 출력 신호

    // 4:1 멀티플렉서 인스턴스화
    param_mux #(
        .N(MUX_N1),
        .WIDTH(MUX_WIDTH)
    ) mux_4 (
        .inputs(inputs_4),   // 펼친 입력
        .select(select_4),   // 선택 신호
        .out(out_4)          // 출력
    );

    // 8:1 멀티플렉서 인스턴스화
    param_mux #(
        .N(MUX_N2),
        .WIDTH(MUX_WIDTH)
    ) mux_8 (
        .inputs(inputs_8),   // 펼친 입력
        .select(select_8),   // 선택 신호
        .out(out_8)          // 출력
    );
    // 첫 번째 MEM (4-bit 주소, 8-bit 데이터)
    parameter MEM_N1 = 4;
    parameter MEM_DATA_WIDTH1 = 8;
    reg clk;
    reg [MEM_N1-1:0] addr1;
    reg [MEM_DATA_WIDTH1-1:0] data_in1;
    reg write_enable1;
    wire [MEM_DATA_WIDTH1-1:0] data_out1;

    // 두 번째 MEM (6-bit 주소, 16-bit 데이터)
    parameter MEM_N2 = 6;
    parameter MEM_DATA_WIDTH2 = 16;
    reg [MEM_N2-1:0] addr2;
    reg [MEM_DATA_WIDTH2-1:0] data_in2;
    reg write_enable2;
    wire [MEM_DATA_WIDTH2-1:0] data_out2;

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

    param_mem #(
        .N(MEM_N2),
        .DATA_WIDTH(MEM_DATA_WIDTH2)
    ) rom2 (
        .clk(clk),
        .addr(addr2),
        .data_in(data_in2),
        .write_enable(write_enable2),
        .data_out(data_out2)
    );

    // 클럭 생성
    always #5 clk = ~clk;
    integer i;
    integer file;  

    // 테스트 시나리오
    initial begin
        file = $fopen("output.txt", "w");
        clk = 0;
        addr1 = 0;
        addr2 = 0;
        data_in1 = 0;
        data_in2 = 0;
        write_enable1 = 0;
        write_enable2 = 0;
        // 4:1 멀티플렉서 입력 초기화
        for (i = 0; i < MUX_N1; i = i + 1) begin
            inputs_4[i*MUX_WIDTH +: MUX_WIDTH] = i * 10 + 1;  // 1, 11, 21, 31
            input_4[i] = inputs_4[i*MUX_WIDTH +: MUX_WIDTH];
        end

        // 8:1 멀티플렉서 입력 초기화
        for (i = 0; i < MUX_N2; i = i + 1) begin
            inputs_8[i*MUX_WIDTH +: MUX_WIDTH] = i * 20 + 5;  // 5, 25, 45, 65, 85, 105, 125, 145
            input_8[i] = inputs_8[i*MUX_WIDTH +: MUX_WIDTH];
        end

        // 4:1 멀티플렉서 테스트
        for (i = 0; i < MUX_N1; i = i + 1) begin
            select_4 = i;
            #10;
            $fdisplay(file,"4:1 MUX - Select: %d, Output: %d", select_4, out_4);
        end

        $fdisplay(file,"",);
        // 8:1 멀티플렉서 테스트
        for (i = 0; i < MUX_N2; i = i + 1) begin
            select_8 = i;
            #10;
            $fdisplay(file,"8:1 MUX - Select: %d, Output: %d", select_8, out_8);
        end

        $fdisplay(file,"",);
        // 추가 테스트: 무작위 선택
        repeat(5) begin
            select_4 = $random % MUX_N1;
            select_8 = $random % MUX_N2;
            #10;
            $fdisplay(file,"Random Test - 4:1 MUX Select: %d, Output: %d", select_4, out_4);
            $fdisplay(file,"Random Test - 8:1 MUX Select: %d, Output: %d", select_8, out_8);
        end
        
        write_enable1 <= 1;
        for (i = 0; i < 2**MEM_N1; i = i + 1) begin
            @(posedge clk);
            addr1 <= i;
            data_in1 <= i * 2;
        end
            @(posedge clk);
        write_enable1 <= 0;

        write_enable2 = 1;
        for (i = 0; i < 2**MEM_N2; i = i + 1) begin
            @(posedge clk);
            addr2 <= i;
            data_in2 <= i * 3;
        end
            @(posedge clk);
        write_enable2 <= 0;
            @(posedge clk);
        $fdisplay(file,"\nMEM1 (4-bit address, 8-bit data) Test:");
        for (i = 0; i < 2**MEM_N1; i = i + 1) begin
            addr1 <= i;
            @(posedge clk);
            #1;
            $fdisplay(file,"Address: %d, Data: %d", addr1, data_out1);
        end

        $fdisplay(file,"\nMEM2 (6-bit address, 16-bit data) Test:");
        for (i = 0; i < 2**MEM_N2; i = i + 1) begin
            addr2 <= i;
            @(posedge clk);
            #1;
            $fdisplay(file,"Address: %d, Data: %d", addr2, data_out2);
        end

        // 무작위 주소 테스트
        $fdisplay(file,"\nRandom Address Test:");
        repeat(5) begin
            addr1 <= $random % (2**MEM_N1);
            addr2 <= $random % (2**MEM_N2);
            @(posedge clk);
            #1;
            $fdisplay(file,"MEM1 - Address: %d, Data: %3d", addr1, data_out1);
            $fdisplay(file,"MEM2 - Address: %d, Data: %3d", addr2, data_out2);
        end
        @(posedge clk);
        $fclose(file);  
        $finish;
    end

endmodule
`endif