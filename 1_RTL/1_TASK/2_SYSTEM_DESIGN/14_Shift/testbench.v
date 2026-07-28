`timescale 1ns / 1ps

module testbench;

// 입력 레지스터 선언
reg clk;
reg load;
reg [3:0] d;

// 출력 와이어 선언
wire [3:0] q;
integer file;  

// 테스트할 모듈 인스턴스화 (수정된 포트명 적용)
shift u_shift (
    .i_clk  ( clk  ),
    .i_load ( load ),
    .i_input   ( d    ),
    .o_out  ( q    )
);

// 클럭 생성
always #5 clk = ~clk;

initial begin
    file = $fopen("output.txt", "w");
    forever begin
        @(posedge clk);
        if (|q !== 1'b0 && |q !== 1'b1) begin
            $display("load = %d, d=%b", load, d);
            $fdisplay(file, "load = %d, d=%b", load, d);
        end else begin
            $display("load = %d, d=%b, q=%b ", load, d, q);
            $fdisplay(file, "load = %d, d=%b, q=%b ", load, d, q);
        end
    end
end

// 테스트 시나리오
initial begin
    // 초기화
    clk = 0;
    load = 1'b0;
    d = 4'b0000;
    
    @(posedge clk);
    d <= 4'b1010;
    load <= 1'b1;
    
    @(posedge clk);
    load <= 1'b0;
    
    // 6번의 클럭 사이클 동안 시프트 동작 확인
    repeat(6) begin
        @(posedge clk);
    end
    
    // 새로운 입력 값으로 테스트
    d <= 4'b1111;
    load <= 1'b1;
    
    @(posedge clk);
    load <= 1'b0;
    
    // 추가로 6번의 클럭 사이클 동안 시프트 동작 확인
    repeat(6) begin
        @(posedge clk);
    end
    
    @(posedge clk);
    @(posedge clk);
    #5;
    
    $fclose(file);
    $finish;
end

endmodule
