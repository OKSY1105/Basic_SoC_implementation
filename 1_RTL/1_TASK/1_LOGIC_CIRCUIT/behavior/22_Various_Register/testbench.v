`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations
    // ==========================================
    wire [1:0]  i_sel;
    reg  [7:0]  in_a;
    reg  [7:0]  in_b;
    wire [7:0]  i_in;
    reg         i_clk;
    reg         i_reset;
    reg         i_areset;

    wire [7:0]  o_out_0;
    wire [7:0]  o_out_1;
    wire [7:0]  o_out_2;
    wire [7:0]  o_out_3;
    wire [7:0]  o_out_4;
    wire [15:0] o_out_5;
    wire [7:0]  o_out_6;

    integer file;

    // ==========================================
    // Module Instantiation
    // ==========================================
    register u_registers (
        .i_clk    ( i_clk    ),
        .i_reset  ( i_reset  ),
        .i_areset ( i_areset ),
        .i_sel    ( i_sel    ),
        .i_in     ( i_in     ),
        .o_out_0  ( o_out_0  ),
        .o_out_1  ( o_out_1  ),
        .o_out_2  ( o_out_2  ),
        .o_out_3  ( o_out_3  ),
        .o_out_4  ( o_out_4  ),
        .o_out_5  ( o_out_5  ),
        .o_out_6  ( o_out_6  )
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    initial begin
        i_clk = 0;
        forever i_clk = #5 ~i_clk;
    end

    // ==========================================
    // Stimulus & Test Sequence
    // ==========================================
    initial begin
        in_a     = 0;
        in_b     = 0;
        i_reset  = 0;
        i_areset = 0;
        
        #36;
        i_areset = 1;
        #26;
        i_areset = 0;
        #66;
        i_areset = 1;
    end

    always @(posedge i_clk) begin
        if (in_a[2]) 
            i_reset <= 1'b1;
        else         
            i_reset <= 1'b0;
    end

    always @(posedge i_clk) begin
        in_a <= in_a + 8'd1;
    end

    always @(negedge i_clk) begin
        in_b <= in_b + 8'd1;
    end

    assign i_sel = in_a[3:2];
    assign i_in  = in_a + in_b;

    // ==========================================
    // File Output Logging
    // ==========================================
    initial begin
        file = $fopen("output.txt", "w");
        
       
        $fmonitor(file, "i_clk = %d, i_reset = %d, i_areset = %d, i_in = %d, o_out_0 = %d, o_out_1 = %d, o_out_2 = %d, o_out_3 = %d, o_out_4 = %d, i_sel = %d, o_out_5 = %h, o_out_6 = %b", 
                  i_clk, i_reset, i_areset, i_in, o_out_0, o_out_1, o_out_2, o_out_3, o_out_4, i_sel, o_out_5, o_out_6);

        wait(in_b == 8'd15);
        #10;
        $fclose(file);
        $finish;
    end

endmodule