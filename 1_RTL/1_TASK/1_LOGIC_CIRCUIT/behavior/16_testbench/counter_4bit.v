`timescale 1ns / 1ps

module counter_4bit (
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,
    output reg  [3:0] count
);

    // 파라미터 및 상수 정의
    localparam [3:0] CNT_INIT = 4'd0;
    localparam [3:0] CNT_STEP = 4'd1;

    // 비동기 리셋 및 인에이블 제어 동기 로직
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= CNT_INIT;
        end else begin
            if (enable) begin
                count <= count + CNT_STEP;
            end else begin
                count <= count; // 현재 값 유지
            end
        end
    end

endmodule
