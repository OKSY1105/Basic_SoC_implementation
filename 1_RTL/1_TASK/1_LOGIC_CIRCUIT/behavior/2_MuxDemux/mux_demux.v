`timescale 1ns / 1ps

module mux_demux (
    i_mux2sel,
    o_mux2sel,
    i_mux4sel,
    o_mux4sel,
    i_demux1to2_sel,
    i_input1to2_sel,
    o_demux1to2_sel
);

    input i_mux2sel;
    output o_mux2sel;

    input [1:0] i_mux4sel;
    output reg [1:0] o_mux4sel; // always 블록에서 쓰이므로 reg 선언

    input i_demux1to2_sel;
    input i_input1to2_sel;      // 중복 선언 수정됨
    output reg [1:0] o_demux1to2_sel; // always 블록에서 쓰이므로 reg 선언

    // 1. Mux 2to1 (삼항 연산자 문법 수정)
    assign o_mux2sel = (i_mux2sel == 0) ? 1 : 0;

    // 2. Mux 4to1
    always @(*) begin
        case(i_mux4sel) // 콜론(:) 제거
            2'b00 : o_mux4sel = 2'd3;
            2'b01 : o_mux4sel = 2'd2;
            2'b10 : o_mux4sel = 2'd1;
            default : o_mux4sel = 2'd0;
        endcase // endcase 추가
    end

    // 3. Demux 1to2
    always @(*) begin
        case(i_demux1to2_sel) // 콜론(:) 제거
            // 선택 신호가 아닌 '입력 데이터'를 출력하도록 수정 및 세미콜론 추가
            1'b0 : o_demux1to2_sel = {1'b0, i_input1to2_sel}; 
            1'b1 : o_demux1to2_sel = {i_input1to2_sel, 1'b0};
            default : o_demux1to2_sel = 2'b00;
        endcase // endcase 추가
    end

endmodule
