module tb_ALU_4bit;

    reg [3:0] i_S;
    reg [3:0] i_A;
    reg [3:0] i_B;
    reg       i_M;
    reg       i_Cin;

    wire       o_Cout;
    wire [3:0] o_out;

    ALU_4bit uut (
        .i_S(i_S),
        .i_A(i_A),
        .i_B(i_B),
        .i_M(i_M),
        .i_Cin(i_Cin),
        .o_Cout(o_Cout),
        .o_out(o_out)
    );

    initial begin
        $shm_open("waves.shm");
        $shm_probe("AS");
    end

    initial begin
        i_A = 4'b0000; 
        i_B = 4'b0000; 
        i_M = 1'b0; 
        i_Cin = 1'b0; 
        i_S = 4'b0000;
        
        $display("--- ALU 4-bit Simulation Start ---");

        #10; 
        i_A = 4'b0101; 
        i_B = 4'b0011; 
        
        i_S = 4'b1001; 
        #10;
        $display("[Arith-ADD] A=%b, B=%b => Cout=%b, Out=%b", i_A, i_B, o_Cout, o_out);

        i_S = 4'b0110; 
        #10;
        $display("[Arith-SUB] A=%b, B=%b => Cout=%b, Out=%b", i_A, i_B, o_Cout, o_out);

        i_S = 4'b1100; 
        #10;
        $display("[Arith-SHIFT] A=%b => Cout=%b, Out=%b", i_A, o_Cout, o_out);

        #10;
        i_Cin = 1'b1;
        i_S = 4'b1001; 
        #10;
        $display("[Arith-Cin=1] A=%b, B=%b => Cout=%b, Out=%b", i_A, i_B, o_Cout, o_out);

        #10;
        i_M = 1'b1;   
        i_Cin = 1'b0; 

        i_S = 4'b1110; 
        #10;
        $display("[Logic-AND] A=%b, B=%b => Out=%b", i_A, i_B, o_out);

        i_S = 4'b1011; 
        #10;
        $display("[Logic-OR]  A=%b, B=%b => Out=%b", i_A, i_B, o_out);

        i_S = 4'b1001; 
        #10;
        $display("[Logic-XOR] A=%b, B=%b => Out=%b", i_A, i_B, o_out);

        #20;
        $display("--- Simulation Finished ---");
        $finish;
    end

endmodule
