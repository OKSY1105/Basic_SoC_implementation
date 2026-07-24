`timescale 1ns / 1ps

module testbench;

// ==========================================
// Signal Declarations
// ==========================================
// 2 to 1
reg  [3:0]    i_mux_2_to_1_0;
reg  [3:0]    i_mux_2_to_1_1;
reg           i_mux_2_to_1_sel;
wire [3:0]    o_mux_2_to_1;

// 9 to 1
reg  [3:0]    i_mux_9_to_1_0;
reg  [3:0]    i_mux_9_to_1_1;
reg  [3:0]    i_mux_9_to_1_2;
reg  [3:0]    i_mux_9_to_1_3;
reg  [3:0]    i_mux_9_to_1_4;
reg  [3:0]    i_mux_9_to_1_5;
reg  [3:0]    i_mux_9_to_1_6;
reg  [3:0]    i_mux_9_to_1_7;
reg  [3:0]    i_mux_9_to_1_8;
reg  [3:0]    i_mux_9_to_1_sel;
wire [3:0]    o_mux_9_to_1;

// 256 to 1
reg  [2047:0] i_mux_256_to_1;
reg  [7:0]    i_mux_256_to_1_sel;
wire [7:0]    o_mux_256_to_1;

// 1 to 2
reg  [3:0]    i_demux_1_to_2;
reg           i_demux_1_to_2_sel;
wire [3:0]    o_demux_1_to_2_0;
wire [3:0]    o_demux_1_to_2_1;

// 1 to 9
reg  [3:0]    i_demux_1_to_9;
reg  [3:0]    i_demux_1_to_9_sel;
wire [3:0]    o_demux_1_to_9_0;
wire [3:0]    o_demux_1_to_9_1;
wire [3:0]    o_demux_1_to_9_2;
wire [3:0]    o_demux_1_to_9_3;
wire [3:0]    o_demux_1_to_9_4;
wire [3:0]    o_demux_1_to_9_5;
wire [3:0]    o_demux_1_to_9_6;
wire [3:0]    o_demux_1_to_9_7;
wire [3:0]    o_demux_1_to_9_8;
wire [35:0]   o_demux_1_to_9_concat;

// 1 to 256
reg  [7:0]    i_demux_1_to_256;
reg  [7:0]    i_demux_1_to_256_sel;
wire [2047:0] o_demux_1_to_256;
reg  [7:0]    o_demux_1_to_256_split[0:255];

integer i;
integer file; // File descriptor for the CSV output file

// ==========================================
// Module Instantiation
// ==========================================
mux_demux u_mux_demux (
    .i_mux_2_to_1_0      ( i_mux_2_to_1_0       ),
    .i_mux_2_to_1_1      ( i_mux_2_to_1_1       ),
    .i_mux_2_to_1_sel    ( i_mux_2_to_1_sel     ),
    .o_mux_2_to_1        ( o_mux_2_to_1         ),

    .i_mux_9_to_1_0      ( i_mux_9_to_1_0       ),
    .i_mux_9_to_1_1      ( i_mux_9_to_1_1       ),
    .i_mux_9_to_1_2      ( i_mux_9_to_1_2       ),
    .i_mux_9_to_1_3      ( i_mux_9_to_1_3       ),
    .i_mux_9_to_1_4      ( i_mux_9_to_1_4       ),
    .i_mux_9_to_1_5      ( i_mux_9_to_1_5       ),
    .i_mux_9_to_1_6      ( i_mux_9_to_1_6       ),
    .i_mux_9_to_1_7      ( i_mux_9_to_1_7       ),
    .i_mux_9_to_1_8      ( i_mux_9_to_1_8       ),
    .i_mux_9_to_1_sel    ( i_mux_9_to_1_sel     ),
    .o_mux_9_to_1        ( o_mux_9_to_1         ),

    .i_mux_256_to_1      ( i_mux_256_to_1       ),
    .i_mux_256_to_1_sel  ( i_mux_256_to_1_sel   ),
    .o_mux_256_to_1      ( o_mux_256_to_1       ),

    .i_demux_1_to_2      ( i_demux_1_to_2       ),
    .i_demux_1_to_2_sel  ( i_demux_1_to_2_sel   ),
    .o_demux_1_to_2_0    ( o_demux_1_to_2_0     ),
    .o_demux_1_to_2_1    ( o_demux_1_to_2_1     ),

    .i_demux_1_to_9      ( i_demux_1_to_9       ),
    .i_demux_1_to_9_sel  ( i_demux_1_to_9_sel   ),
    .o_demux_1_to_9_0    ( o_demux_1_to_9_0     ),
    .o_demux_1_to_9_1    ( o_demux_1_to_9_1     ),
    .o_demux_1_to_9_2    ( o_demux_1_to_9_2     ),
    .o_demux_1_to_9_3    ( o_demux_1_to_9_3     ),
    .o_demux_1_to_9_4    ( o_demux_1_to_9_4     ),
    .o_demux_1_to_9_5    ( o_demux_1_to_9_5     ),
    .o_demux_1_to_9_6    ( o_demux_1_to_9_6     ),
    .o_demux_1_to_9_7    ( o_demux_1_to_9_7     ),
    .o_demux_1_to_9_8    ( o_demux_1_to_9_8     ),

    .i_demux_1_to_256    ( i_demux_1_to_256     ),
    .i_demux_1_to_256_sel( i_demux_1_to_256_sel ),
    .o_demux_1_to_256    ( o_demux_1_to_256     )
);

// Splitting o_demux_1_to_256 into 256 separate 8-bit values
always @(*) begin
    for (i = 0; i < 256; i = i + 1) begin
        o_demux_1_to_256_split[i] = o_demux_1_to_256[i*8 +: 8];  
    end
end

assign o_demux_1_to_9_concat = {o_demux_1_to_9_8,
                                o_demux_1_to_9_7,
                                o_demux_1_to_9_6,
                                o_demux_1_to_9_5,
                                o_demux_1_to_9_4,
                                o_demux_1_to_9_3,
                                o_demux_1_to_9_2,
                                o_demux_1_to_9_1,
                                o_demux_1_to_9_0};

// ==========================================
// Test Stimulus Block
// ==========================================
initial begin
    $timeformat(-9, 0, "ns", 6);

    // Open a file for CSV output
    file = $fopen("output.txt", "w");
    
    // Write the CSV header
    $fdisplay(file, " Time,m2_sel,m2_o,m9_s,m9_o,m256_s,m256_o,dm2_s,dm2_o0,dm2_o1,dm9_s, dm9_outs,dm256_s,dm256_outs");
    
    // Monitor and write to CSV simultaneously
  /*  $fmonitor(file, "%t,     %h,   %h,   %h,   %h,    %h,    %h,    %h,     %h,     %h,    %h,%h,     %h,%h", 
              $time, 
              i_mux_2_to_1_sel, o_mux_2_to_1, 
              i_mux_9_to_1_sel, o_mux_9_to_1, 
              i_mux_256_to_1_sel, o_mux_256_to_1, 
              i_demux_1_to_2_sel, o_demux_1_to_2_0, o_demux_1_to_2_1, 
              i_demux_1_to_9_sel, o_demux_1_to_9_concat,
              i_demux_1_to_256_sel, o_demux_1_to_256 );*/

    // Initial signal values
    i_mux_2_to_1_0 = 4'd3;
    i_mux_2_to_1_1 = 4'd12;
    i_mux_2_to_1_sel = 0;

    i_mux_9_to_1_0 = 1;
    i_mux_9_to_1_1 = 2;
    i_mux_9_to_1_2 = 3;
    i_mux_9_to_1_3 = 4;
    i_mux_9_to_1_4 = 5;
    i_mux_9_to_1_5 = 6;
    i_mux_9_to_1_6 = 7;
    i_mux_9_to_1_7 = 8;
    i_mux_9_to_1_8 = 9;
    i_mux_9_to_1_sel = 0;

    for (i = 0; i < 256; i = i + 1)
        i_mux_256_to_1[i*8 +: 8] = i;
    i_mux_256_to_1_sel = 0;

    i_demux_1_to_2 = 4'hF;
    i_demux_1_to_2_sel = 0;

    i_demux_1_to_9 = 4'hF;
    i_demux_1_to_9_sel = 0;

    i_demux_1_to_256 = 8'hFF;
    i_demux_1_to_256_sel = 0;

    // Run the test
    #10;
    repeat(255) begin
	     $fdisplay(file, "%t,     %h,   %h,   %h,   %h,    %h,    %h,    %h,     %h,     %h,    %h,%h,     %h,%h",
           	   $time,
            	   i_mux_2_to_1_sel, o_mux_2_to_1,
           	   i_mux_9_to_1_sel, o_mux_9_to_1,
         	   i_mux_256_to_1_sel, o_mux_256_to_1,
           	   i_demux_1_to_2_sel, o_demux_1_to_2_0, o_demux_1_to_2_1,
           	   i_demux_1_to_9_sel, o_demux_1_to_9_concat,
           	   i_demux_1_to_256_sel, o_demux_1_to_256 );

        i_mux_2_to_1_sel     = i_mux_2_to_1_sel + 1;
        i_mux_9_to_1_sel     = i_mux_9_to_1_sel + 1;
        i_mux_256_to_1_sel   = i_mux_256_to_1_sel + 1;
        i_demux_1_to_2_sel   = i_demux_1_to_2_sel + 1;
        i_demux_1_to_9_sel   = i_demux_1_to_9_sel + 1;
        i_demux_1_to_256_sel = i_demux_1_to_256_sel + 1;
        #10;
    end

    // Close the file after simulation
    $fclose(file);
    $finish;
end

endmodule
