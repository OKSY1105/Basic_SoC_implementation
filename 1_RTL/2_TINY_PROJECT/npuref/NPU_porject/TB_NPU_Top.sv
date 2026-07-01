`timescale 1ns / 1ps

`define pretrained

`include "include.v"

module TB_NPU_Top();

reg clk, rst_n;
reg start_inference;
reg [4*`dataWidth-1:0] input_pixels;
reg input_valid;
wire done;
wire [31:0] results [3:0];

reg [`dataWidth-1:0] img_mem_0 [784:0];
reg [`dataWidth-1:0] img_mem_1 [784:0];
reg [`dataWidth-1:0] img_mem_2 [784:0];
reg [`dataWidth-1:0] img_mem_3 [784:0];

reg [`dataWidth-1:0] captured_l1_out [0:29];
reg [`dataWidth-1:0] captured_l2_out [0:19];
reg [`dataWidth-1:0] captured_l3_out [0:9];

integer i;

NPU_Top #(.dataWidth(`dataWidth)) dut (
    .clk(clk), .rst_n(rst_n), .start_inference(start_inference),
    .input_pixels(input_pixels), .input_valid(input_valid),
    .done_interrupt(done),
    .result_class_0(results[0]), .result_class_1(results[1]),
    .result_class_2(results[2]), .result_class_3(results[3])
);

always #5 clk = ~clk;

initial begin
    clk = 0; rst_n = 0;
    start_inference = 0; input_valid = 0;
    input_pixels = 0;
    
    for(i=0; i<=784; i=i+1) begin
        img_mem_0[i] = 0; img_mem_1[i] = 0; img_mem_2[i] = 0; img_mem_3[i] = 0;
    end
    
    for(i=0; i<30; i=i+1) captured_l1_out[i] = 0;
    for(i=0; i<20; i=i+1) captured_l2_out[i] = 0;
    for(i=0; i<10; i=i+1) captured_l3_out[i] = 0;
    
    $readmemb("test_data_0000.txt", img_mem_0);
    $readmemb("test_data_0000.txt", img_mem_1);  // ✅ 추가
    $readmemb("test_data_0000.txt", img_mem_2);  // ✅ 추가
    $readmemb("test_data_0000.txt", img_mem_3);  // ✅ 추가
    
    #100 rst_n = 1;
    #20 start_inference = 1;
    #10 start_inference = 0;
    
    wait(dut.state == 1);
end

reg [3:0] prev_state;

always @(posedge clk) begin
    prev_state <= dut.state;
    
    if (dut.state == 1) begin
        if (dut.k_cnt < 784) begin
            input_pixels <= {img_mem_3[dut.k_cnt], img_mem_2[dut.k_cnt], img_mem_1[dut.k_cnt], img_mem_0[dut.k_cnt]};
            input_valid <= 1;
        end else begin
            input_valid <= 0;
        end
    end else begin
        input_valid <= 0;
    end
    
    // Layer 1 캡처 (조용히)
    if (dut.state == 2 && dut.buf_wen && dut.buf_w_addr < 30) begin
        captured_l1_out[dut.buf_w_addr] = dut.buf_w_data;
    end
    
    // Layer 1 완료 출력
    if (prev_state == 2 && dut.state == 3) begin
        $display("\n============================================================");
        $display("[TB] Layer 1 Calculation Complete!");
        $write("[ ");
        for(i=0; i<30; i=i+1) begin
            $write("%4d ", $signed(captured_l1_out[i]));
            if ((i+1)%10 == 0 && i != 29) $write("\n  ");
        end
        $write(" ]\n");
        $display("============================================================\n");
    end
    
    // Layer 2 캡처 (조용히)
    if (dut.state == 4 && dut.buf_wen && dut.buf_w_addr < 20) begin
        captured_l2_out[dut.buf_w_addr] = dut.buf_w_data;
    end
    
    // Layer 2 완료 출력
    if (prev_state == 4 && dut.state == 5) begin
        $display("\n============================================================");
        $display("[TB] Layer 2 Calculation Complete!");
        $write("[ ");
        for(i=0; i<20; i=i+1) begin
            $write("%4d ", $signed(captured_l2_out[i]));
            if ((i+1)%10 == 0 && i != 19) $write("\n  ");
        end
        $write(" ]\n");
        $display("============================================================\n");
    end
    
    // Layer 3 캡처 (조용히)
    if (dut.state == 6 && dut.buf_wen && dut.buf_w_addr < 10) begin
        captured_l3_out[dut.buf_w_addr] = dut.buf_w_data;
    end
    
    // Layer 3 완료 출력
    if (prev_state == 6 && dut.state == 7) begin
        $display("\n============================================================");
        $display("[TB] Layer 3 Calculation Complete!");
        $write("[ ");
        for(i=0; i<10; i=i+1) begin
            $write("%4d ", $signed(captured_l3_out[i]));
        end
        $write(" ]\n");
        $display("============================================================\n");
    end
    
    // 최종 결과 출력
    if (done) begin
        $display("\n============================================================");
        $display("[TB] Inference DONE at time %0t", $time);
        
        repeat(20) @(posedge clk);
        
        $display("------------------------------------------------------------");
        $display("[TB] [Image 0] Result: %0d | Expected: %0d", results[0], img_mem_0[784]);
        if (results[0] == img_mem_0[784]) 
            $display("[TB] >>> PASS <<<"); 
        else 
            $display("[TB] >>> FAIL <<<");
        
        $display("============================================================");
        $finish;
    end
end

endmodule