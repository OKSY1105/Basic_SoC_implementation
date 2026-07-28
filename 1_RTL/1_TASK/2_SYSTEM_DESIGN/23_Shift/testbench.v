`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg                     i_clk;
    reg                     i_areset;
    reg  [3:0]              i_bit_data;
    reg  [31:0]             i_byte_data;
    reg                     i_load;
    reg                     i_en;

    wire [3:0]              o_out_bit_r_logical_shift;
    wire [3:0]              o_out_bit_l_logical_shift;
    wire [31:0]             o_out_byte_r_logical_shift;
    wire [31:0]             o_out_byte_l_logical_shift;
    wire signed [3:0]       o_out_bit_r_arithmetic_shift;
    wire signed [31:0]      o_out_byte_r_arithmetic_shift;
    wire [3:0]              o_out_bit_r_rotate;
    wire [3:0]              o_out_bit_l_rotate;
    wire [31:0]             o_out_byte_r_rotate;
    wire [31:0]             o_out_byte_l_rotate;

    integer file;

    // ==========================================
    // Module Instantiation
    // ==========================================
    shift u_shift (
        .i_clk                         (i_clk),
        .i_areset                      (i_areset),
        .i_bit_data                    (i_bit_data),
        .i_byte_data                   (i_byte_data),
        .i_load                        (i_load),
        .i_en                          (i_en),
        .o_out_bit_r_logical_shift     (o_out_bit_r_logical_shift),
        .o_out_bit_l_logical_shift     (o_out_bit_l_logical_shift),
        .o_out_byte_r_logical_shift    (o_out_byte_r_logical_shift),
        .o_out_byte_l_logical_shift    (o_out_byte_l_logical_shift),
        .o_out_bit_r_arithmetic_shift  (o_out_bit_r_arithmetic_shift),
        .o_out_byte_r_arithmetic_shift (o_out_byte_r_arithmetic_shift),
        .o_out_bit_r_rotate            (o_out_bit_r_rotate),
        .o_out_bit_l_rotate            (o_out_bit_l_rotate),
        .o_out_byte_r_rotate           (o_out_byte_r_rotate),
        .o_out_byte_l_rotate           (o_out_byte_l_rotate)
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    initial begin
        i_clk = 0;
        forever i_clk = #5 ~i_clk;
    end

    // ==========================================
    // Reset Generation
    // ==========================================
    initial begin
        i_areset = 0;
        #4;
        i_areset = 1;
        #4;
        i_areset = 0;
    end

    // ==========================================
    // Stimulus Generation
    // ==========================================
    initial begin
        // 초기값 설정
        i_bit_data  = 4'b0000;
        i_byte_data = 32'h00000000;
        i_load      = 0;
        i_en        = 0;

        @(posedge i_clk) #1 i_load = 1; i_en = 0; i_bit_data = 4'b1101; i_byte_data = 32'hA5A500A5;
        @(posedge i_clk) #1 i_load = 0; 
        @(posedge i_clk) #1 i_en   = 1;
    end

    // ==========================================
    // File Output & Simulation Control
    // ==========================================
    initial begin
        $timeformat(-9, 0, "ns", 4); // -9: ns, 0: decimal place, "ns": unit, 4: minimum field width

        file = $fopen("output.txt", "w");
        $fwrite(file, "Time, arst, load, en, bt_data, by_data, obt_rl_sh, obt_ll_sh, oby_rl_sh, oby_ll_sh, obt_ra_sh, oby_ra_sh, obt_r_ro, obt_l_ro, oby_r_ro, oby_l_ro\n");

        repeat(9) @(posedge i_clk);
        
        #10;
        $fclose(file); 
        $finish;
    end

    // ==========================================
    // File Logging
    // ==========================================
    always @(posedge i_clk) begin
        $fwrite(file, "%t,    %b,    %b,  %b,    %b, %h,      %b,      %b,  %h,  %h,      %b,  %h,     %b,     %b, %h, %h\n",
            $time, i_areset, i_load, i_en, i_bit_data, i_byte_data, 
            o_out_bit_r_logical_shift, o_out_bit_l_logical_shift, o_out_byte_r_logical_shift, o_out_byte_l_logical_shift, 
            o_out_bit_r_arithmetic_shift, o_out_byte_r_arithmetic_shift, 
            o_out_bit_r_rotate, o_out_bit_l_rotate, o_out_byte_r_rotate, o_out_byte_l_rotate);
    end

endmodule