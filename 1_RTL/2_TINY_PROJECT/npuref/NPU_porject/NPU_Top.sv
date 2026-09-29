`include "include.v"
//debug point4
module NPU_Top #(
    parameter dataWidth = 8 
)(
    input clk,
    input rst_n,
    
    input start_inference,
    input [4*dataWidth-1:0] input_pixels,
    input input_valid,
    output reg done_interrupt,
    output [31:0] result_class_0,
    output [31:0] result_class_1,
    output [31:0] result_class_2,
    output [31:0] result_class_3
);

    localparam IDLE = 0, CALC_L1 = 1, BUFFER_WR_L1 = 2, 
               CALC_L2 = 3, BUFFER_WR_L2 = 4,
               CALC_L3 = 5, BUFFER_WR_L3 = 6, 
               OUTPUT_SCAN = 7, DONE = 8;
    
    reg [3:0] state;

    reg [31:0] k_cnt;
    reg [31:0] group_cnt;
    reg [4:0]  write_seq_cnt; 
    
    reg [31:0] cur_layer_num;
    reg [31:0] cur_input_len;
    reg [31:0] cur_neuron_total;
    reg cur_act_sel; 
    
    reg pe_rst, pe_en;
    wire [4*4*`accWidth-1:0] array_out;
    reg [4*dataWidth-1:0] sys_col_in;
    reg [4*dataWidth-1:0] sys_row_in;
    
    wire [4*dataWidth-1:0] w_bank_out;
    wire [4*2*dataWidth-1:0] b_bank_out; 
    
    reg buf_wen;
    reg [31:0] buf_w_addr;
    reg [dataWidth-1:0] buf_w_data;
    wire [dataWidth-1:0] buf_r_data [3:0];
    wire [31:0] buf_r_addr [3:0];
    

    wire [`accWidth-1:0] au_in_psum;
    wire [2*dataWidth-1:0] au_in_bias;
    wire [dataWidth-1:0] act_out_val;
    
    wire [`accWidth-1:0] pe_res_unpacked [3:0][3:0]; 
    wire [2*dataWidth-1:0] bias_unpacked [3:0]; 
    
    wire [`accWidth-1:0] debug_mul_00;

    wire [1:0] in_img_idx;
    wire [1:0] in_neu_idx;
    wire [4:0] delayed_seq_cnt;
    wire [1:0] wr_img_idx;
    wire [1:0] wr_neu_idx;
    wire [31:0] wr_global_neuron_idx; 

    assign in_img_idx = write_seq_cnt[3:2];
    assign in_neu_idx = write_seq_cnt[1:0];
    assign delayed_seq_cnt = write_seq_cnt - 1;
    assign wr_img_idx = delayed_seq_cnt[3:2];
    assign wr_neu_idx = delayed_seq_cnt[1:0];
    assign wr_global_neuron_idx = group_cnt * 4 + wr_neu_idx;

    assign au_in_psum = pe_res_unpacked[in_img_idx][in_neu_idx];
    assign au_in_bias = bias_unpacked[in_neu_idx];

    // ✅ 수정: OUTPUT_SCAN 상태에서 올바른 주소 사용
    assign buf_r_addr[0] = (state == OUTPUT_SCAN || state == DONE) ? k_cnt : (0 * 32) + k_cnt;
    assign buf_r_addr[1] = (state == OUTPUT_SCAN || state == DONE) ? (1 * 32) + k_cnt : (1 * 32) + k_cnt;
    assign buf_r_addr[2] = (state == OUTPUT_SCAN || state == DONE) ? (2 * 32) + k_cnt : (2 * 32) + k_cnt;
    assign buf_r_addr[3] = (state == OUTPUT_SCAN || state == DONE) ? (3 * 32) + k_cnt : (3 * 32) + k_cnt;

    // --- Modules ---

    Weight_Bank #(.dataWidth(dataWidth)) wb (
        .clk(clk), .layer_idx(cur_layer_num), .neuron_group(group_cnt), .w_addr(k_cnt), .w_out_packed(w_bank_out)
    );
    
    Bias_Bank #(.dataWidth(dataWidth)) bb ( 
        .clk(clk), .layer_idx(cur_layer_num), .neuron_group(group_cnt), .b_out_packed(b_bank_out)
    );

    Systolic_Array #(.dataWidth(dataWidth)) sa (
        .clk(clk), .rst(pe_rst), .en(pe_en), .row_in(sys_row_in), .col_in(sys_col_in), .array_out(array_out),
        .debug_pe00_mul(debug_mul_00)
    );
    
    Activation_Unit #(.dataWidth(dataWidth)) au (
        .clk(clk), .psum_in(au_in_psum), .bias_in(au_in_bias), .act_sel(cur_act_sel), .out(act_out_val)
    );
    
    Global_Buffer #(.dataWidth(dataWidth)) gb (
        .clk(clk), .wen(buf_wen), .w_addr(buf_w_addr), .w_data(buf_w_data),
        .r_addr_0(buf_r_addr[0]), .r_addr_1(buf_r_addr[1]), .r_addr_2(buf_r_addr[2]), .r_addr_3(buf_r_addr[3]),
        .r_data_0(buf_r_data[0]), .r_data_1(buf_r_data[1]), .r_data_2(buf_r_data[2]), .r_data_3(buf_r_data[3])
    );
    
    // MaxFinder
    reg [10*dataWidth-1:0] mf_in_data [3:0]; 
    reg mf_valid_pulse;
    wire [31:0] mf_out [3:0];
    wire [3:0] mf_out_valid;

    genvar img;
    generate
        for(img=0; img<4; img=img+1) begin : MAX_FINDER_GEN
            maxFinder #(.numInput(10), .inputWidth(dataWidth)) mf (
                .i_clk(clk), .i_data(mf_in_data[img]), .i_valid(mf_valid_pulse),
                .o_data(mf_out[img]), .o_data_valid(mf_out_valid[img])
            );
        end
    endgenerate

    assign result_class_0 = mf_out[0];
    assign result_class_1 = mf_out[1];
    assign result_class_2 = mf_out[2];
    assign result_class_3 = mf_out[3];

    genvar i, j;
    generate
        for(i=0; i<4; i=i+1) begin : UNPACK_IMG
            for(j=0; j<4; j=j+1) begin : UNPACK_NEURON
                assign pe_res_unpacked[i][j] = array_out[((i*4+j)+1)*`accWidth-1 : (i*4+j)*`accWidth];
            end
        end
        for(j=0; j<4; j=j+1) begin : UNPACK_BIAS
            assign bias_unpacked[j] = b_bank_out[(j+1)*2*dataWidth-1 : j*2*dataWidth];
        end
    endgenerate

    // --- Control FSM ---
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k_cnt <= 0;
            group_cnt <= 0;
            write_seq_cnt <= 0;
            pe_rst <= 1;
            pe_en <= 0;
            buf_wen <= 0;
            done_interrupt <= 0;
            mf_valid_pulse <= 0;

            sys_row_in <= 0;
            sys_col_in <= 0;
            
        end else begin
            buf_wen <= 0;
            mf_valid_pulse <= 0;
            
            case(state)
                IDLE: begin
                    if(start_inference) begin
                        state <= CALC_L1;
                        cur_layer_num <= 1;
                        cur_input_len <= `numWeightLayer1; 
                        cur_neuron_total <= `numNeuronLayer1; 
                        cur_act_sel <= 1; 
                        k_cnt <= 0;
                        group_cnt <= 0;
                        pe_rst <= 1; 
                        sys_row_in <= 0;
                        sys_col_in <= 0;
                    end
                end
                
                CALC_L1: begin
                    pe_rst <= 0;
                    if (k_cnt == 0) pe_en <= 0;
                    else if (k_cnt <= cur_input_len) pe_en <= 1;
                    else pe_en <= 0;
                    
                    sys_row_in <= input_pixels;
                    sys_col_in <= w_bank_out;

                    if (k_cnt == cur_input_len + 1) begin
                        pe_en <= 0;
                        state <= BUFFER_WR_L1;
                        write_seq_cnt <= 0;
                    end else begin
                        k_cnt <= k_cnt + 1;
                    end
                end
                
                BUFFER_WR_L1: begin
                    if (write_seq_cnt > 0 && write_seq_cnt <= 16) begin
                        if (wr_global_neuron_idx < cur_neuron_total) begin 
                            // WRITE TO BUFFER 1
                            buf_wen <= 1;
                            buf_w_addr <= (wr_img_idx * 32) + wr_global_neuron_idx;
                            buf_w_data <= act_out_val; 
                        end
                    end

                    if (write_seq_cnt == 16) begin
                        if ((group_cnt + 1) * 4 >= cur_neuron_total) begin
                            state <= CALC_L2;
                            cur_layer_num <= 2;
                            cur_input_len <= `numNeuronLayer1; 
                            cur_neuron_total <= `numNeuronLayer2; 
                            cur_act_sel <= 1; 
                            group_cnt <= 0;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end else begin
                            state <= CALC_L1;
                            group_cnt <= group_cnt + 1;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end
                        write_seq_cnt <= 0;
                    end else begin
                        write_seq_cnt <= write_seq_cnt + 1;
                    end
                end
                
                CALC_L2: begin
                    pe_rst <= 0;
                    if (k_cnt == 0) pe_en <= 0;
                    else if (k_cnt <= cur_input_len) pe_en <= 1;
                    else pe_en <= 0;

                    sys_row_in <= {buf_r_data[3], buf_r_data[2], buf_r_data[1], buf_r_data[0]};
                    sys_col_in <= w_bank_out;

                    if (k_cnt == cur_input_len + 1) begin
                         state <= BUFFER_WR_L2;
                         pe_en <= 0;
                         write_seq_cnt <= 0;
                    end else begin
                        k_cnt <= k_cnt + 1;
                    end
                end

                BUFFER_WR_L2: begin
                    if (write_seq_cnt > 0 && write_seq_cnt <= 16) begin
                        if (wr_global_neuron_idx < cur_neuron_total) begin
                            // WRITE TO BUFFER 2
                            buf_wen <= 1;
                            buf_w_addr <= (wr_img_idx * 32) + wr_global_neuron_idx; 
                            buf_w_data <= act_out_val;
                        end
                    end

                    if (write_seq_cnt == 16) begin
                        if ((group_cnt + 1) * 4 >= cur_neuron_total) begin
                            state <= CALC_L3;
                            cur_layer_num <= 3;
                            cur_input_len <= `numNeuronLayer2; 
                            cur_neuron_total <= `numNeuronLayer3; 
                            cur_act_sel <= 1; 
                            group_cnt <= 0;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end else begin
                            state <= CALC_L2;
                            group_cnt <= group_cnt + 1;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end
                        write_seq_cnt <= 0;
                    end else begin
                        write_seq_cnt <= write_seq_cnt + 1;
                    end
                end

                CALC_L3: begin
                    pe_rst <= 0;
                    if (k_cnt == 0) pe_en <= 0;
                    else if (k_cnt <= cur_input_len) pe_en <= 1;
                    else pe_en <= 0;

                    sys_row_in <= {buf_r_data[3], buf_r_data[2], buf_r_data[1], buf_r_data[0]};
                    sys_col_in <= w_bank_out;
                    
                    if (k_cnt == cur_input_len + 1) begin
                         state <= BUFFER_WR_L3;
                         pe_en <= 0;
                         write_seq_cnt <= 0;
                    end else begin
                        k_cnt <= k_cnt + 1;
                    end
                end
                
                BUFFER_WR_L3: begin
                    if (write_seq_cnt > 0 && write_seq_cnt <= 16) begin
                        if (wr_global_neuron_idx < cur_neuron_total) begin
                            // WRITE TO BUFFER 3
                            buf_wen <= 1;
                            buf_w_addr <= (wr_img_idx * 32) + wr_global_neuron_idx;
                            buf_w_data <= act_out_val;
                        end
                    end
                    
                     if (write_seq_cnt == 16) begin
                         if ((group_cnt + 1) * 4 >= cur_neuron_total) begin
                            state <= OUTPUT_SCAN;
                            k_cnt <= 0;
                            
                        end else begin
                            state <= CALC_L3;
                            group_cnt <= group_cnt + 1;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end
                        write_seq_cnt <= 0;
                    end else begin
                        write_seq_cnt <= write_seq_cnt + 1;
                    end
                end
                
                // ✅ 수정: OUTPUT_SCAN 로직 개선
                OUTPUT_SCAN: begin
                    if (k_cnt < 10) begin
                        mf_in_data[0][k_cnt*dataWidth +: dataWidth] <= buf_r_data[0];
                        mf_in_data[1][k_cnt*dataWidth +: dataWidth] <= buf_r_data[1];
                        mf_in_data[2][k_cnt*dataWidth +: dataWidth] <= buf_r_data[2];
                        mf_in_data[3][k_cnt*dataWidth +: dataWidth] <= buf_r_data[3];
                        k_cnt <= k_cnt + 1;
                    end else if (k_cnt == 10) begin
                        // ✅ 마지막 데이터(주소 9)가 도착할 때까지 1 사이클 대기
                        k_cnt <= k_cnt + 1;
                    end else if (k_cnt == 11) begin
                        // ✅ 이제 모든 데이터가 mf_in_data에 안정화됨
                        mf_valid_pulse <= 1;
                        state <= DONE;
                        done_interrupt <= 1;
                    end
                end
                
                DONE: begin
                   // Inference Complete
                end
            endcase
        end
    end

    // --- Debug Monitor ---
    `ifdef DEBUG
    integer d_i;
    always @(posedge clk) begin
        // Monitor Layer 1
        if (state == CALC_L1 && pe_en && group_cnt == 0) begin
            $display("[DUT_DEBUG_L1] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Acc=%d", 
                     $time, k_cnt, 
                     $signed(sys_row_in[dataWidth-1:0]), 
                     $signed(sys_col_in[dataWidth-1:0]), 
                     $signed(debug_mul_00),
                     $signed(pe_res_unpacked[0][0]));
        end
        
        // [Modified] Monitor Layer 2 All Groups
        if (state == CALC_L2 && pe_en) begin
            // Check Groups 0, 1, 2...
            // Only print if global neuron idx is valid.
            // L2 has 20 neurons -> 5 groups (0 to 4).
            if (group_cnt <= 4) begin
                for(d_i=0; d_i<4; d_i=d_i+1) begin
                    $display("[DUT_DEBUG_L2_Grp%0d_N%0d] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Acc=%d", 
                             group_cnt, 
                             group_cnt * 4 + d_i, // Global Neuron Index
                             $time, k_cnt, 
                             $signed(sys_row_in[dataWidth-1:0]), // Input (Img0)
                             $signed(sys_col_in[(d_i+1)*dataWidth-1 -: dataWidth]), // Weight for this column
                             // Calculate Mul for verification
                             $signed(sys_row_in[dataWidth-1:0]) * $signed(sys_col_in[(d_i+1)*dataWidth-1 -: dataWidth]),
                             $signed(pe_res_unpacked[0][d_i])); // Acc
                end
            end
        end
    end
    `endif

endmodule