`include "include.v"
module Weight_Memory #(
    parameter numWeight = 3, 
    neuronNo=5,
    layerNo=1,
    addressWidth=10,
    dataWidth=16,
    weightFile="w_1_15.mif"
)(
    input clk,
    input wen,
    input ren,
    input [addressWidth-1:0] wadd,
    input [addressWidth-1:0] radd,
    input [dataWidth-1:0] win,
    output reg [dataWidth-1:0] wout
);

    reg [dataWidth-1:0] mem [numWeight-1:0];
    
    // ========== 수정: 테스트용 기본값 설정 ==========
    integer idx;
    initial begin
        // 기본값으로 1 설정 (테스트용)
        for(idx=0; idx<numWeight; idx=idx+1) begin
            mem[idx] = 8'd1;  // 모든 Weight를 1로 초기화
        end
        
        `ifdef pretrained
            // 파일 로딩 시도 (실패해도 계속 진행)
            $readmemb(weightFile, mem);
        `endif
    end
    // ==============================================
    
    always @(posedge clk) begin
        if (wen) begin
            mem[wadd] <= win;
        end
    end
    
    always @(posedge clk) begin
        if (ren) begin
            wout <= mem[radd];
        end
    end
    
endmodule