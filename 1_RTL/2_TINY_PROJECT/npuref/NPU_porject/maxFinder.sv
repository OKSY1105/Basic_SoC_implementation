module maxFinder #(
    parameter numInput = 10,
    parameter inputWidth = 16
)(
    input i_clk,
    input [(numInput*inputWidth)-1:0] i_data,
    input i_valid,
    output reg [31:0] o_data,
    output reg o_data_valid
);

reg signed [inputWidth-1:0] maxValue;
reg [31:0] maxIndex;
integer i;

always @(posedge i_clk) begin
    o_data_valid <= 1'b0;
    
    if(i_valid) begin
        // 초기화: 첫 번째 값으로 시작
        maxValue = $signed(i_data[inputWidth-1:0]);
        maxIndex = 0;
        
        // 나머지 값들과 비교
        for(i = 1; i < numInput; i = i + 1) begin
            if($signed(i_data[i*inputWidth +: inputWidth]) > maxValue) begin
                maxValue = $signed(i_data[i*inputWidth +: inputWidth]);
                maxIndex = i;
            end
        end
        
        o_data <= maxIndex;
        o_data_valid <= 1'b1;
        
        // 디버깅 출력 추가
        $display("[maxFinder] Time=%0t | Values: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d | Max=%0d at index=%0d", 
                 $time,
                 $signed(i_data[0*inputWidth +: inputWidth]),
                 $signed(i_data[1*inputWidth +: inputWidth]),
                 $signed(i_data[2*inputWidth +: inputWidth]),
                 $signed(i_data[3*inputWidth +: inputWidth]),
                 $signed(i_data[4*inputWidth +: inputWidth]),
                 $signed(i_data[5*inputWidth +: inputWidth]),
                 $signed(i_data[6*inputWidth +: inputWidth]),
                 $signed(i_data[7*inputWidth +: inputWidth]),
                 $signed(i_data[8*inputWidth +: inputWidth]),
                 $signed(i_data[9*inputWidth +: inputWidth]),
                 maxValue, maxIndex);
    end
end

endmodule


