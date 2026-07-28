`timescale 1ns / 1ps

module testbench;

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg        i_clk;
    reg        i_reset;
    reg  [7:0] i_time_val;
    reg        i_cnt_en;

    wire [7:0] o_cnt;   
    wire [7:0] o_decade;   
    wire [7:0] o_en_cnt;   
    wire       o_time_en;   
    wire [7:0] o_time_cnt;   
    wire [4:0] o_clock_h;   
    wire [5:0] o_clock_m;   
    wire [5:0] o_clock_s;

    integer file;  

    // ==========================================
    // Module Instantiation
    // ==========================================
    counter u_counter (
        .i_clk        ( i_clk      ),
        .i_reset      ( i_reset    ),
        .i_time_val   ( i_time_val ),
        .i_cnt_en     ( i_cnt_en   ),
        .o_cnt        ( o_cnt      ),   
        .o_decade     ( o_decade   ),   
        .o_en_cnt     ( o_en_cnt   ),   
        .o_time_en    ( o_time_en  ),   
        .o_time_cnt   ( o_time_cnt ),   
        .o_clock_h    ( o_clock_h  ),   
        .o_clock_m    ( o_clock_m  ),   
        .o_clock_s    ( o_clock_s  )
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    initial begin
        i_clk = 0;
        forever i_clk = #5 ~i_clk;
    end

    // ==========================================
    // Reset & Stimulus
    // ==========================================
    initial begin
        i_time_val = 30;
        i_reset    = 0;
        #5;
        i_reset    = 1;
        #5;
        i_reset    = 0;
    end

    initial begin
        file = $fopen("output.txt", "w");
        i_cnt_en = 0;

        forever begin
            repeat(5) @(posedge i_clk);
            #1 i_cnt_en = 1;
            @(posedge i_clk);
            #1 i_cnt_en = 0;
        end
    end

    // ==========================================
    // Logging & Checker
    // ==========================================
    always @(posedge i_clk) begin
        $fdisplay(file, "i_reset = %d, o_cnt = %3d, o_decade = %2h, i_cnt_en = %1d, o_en_cnt = %3d, i_time_val = %2d, o_time_cnt = %2d, o_time_en = %1d, o_clock_h = %1d, o_clock_m = %2d, o_clock_s = %2d", 
                  i_reset, o_cnt, o_decade, i_cnt_en, o_en_cnt, i_time_val, o_time_cnt, o_time_en, o_clock_h, o_clock_m, o_clock_s);
	  $fflush(file);
    end

    initial begin
        wait(o_clock_h == 5'd1);
        @(posedge i_clk);
        #10;
        $fclose(file);  
        $finish;
    end

endmodule
