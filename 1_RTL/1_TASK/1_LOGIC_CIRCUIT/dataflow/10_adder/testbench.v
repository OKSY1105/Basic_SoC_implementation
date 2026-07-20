`timescale 1ns / 1ps

module testbench;

    // Inputs
    reg [3:0] i_a;
    reg [3:0] i_b;
    reg i_cin;

    // Outputs
    wire [3:0] o_sum;
    wire o_cout;

    // UUT (Unit Under Test) 인스턴스화
    adder uut (
        .i_a(i_a),
        .i_b(i_b),
        .i_cin(i_cin),
        .o_sum(o_sum),
        .o_cout(o_cout)
    );

    initial begin
        // 입력 초기화
        i_a = 0;
        i_b = 0;
        i_cin = 0;

        // 글로벌 리셋 대기 (100 ns)
        #100;
        
        $display("==================================================");
        $display("Time\ti_a\ti_b\ti_cin\t|\to_sum\to_cout");
        $display("==================================================");

        // 테스트 케이스 1
        i_a = 4'b0010; i_b = 4'b0101; i_cin = 0;
        #10;
        $display("%0dns\t%b\t%b\t%b\t|\t%b\t%b", $time, i_a, i_b, i_cin, o_sum, o_cout);

        // 테스트 케이스 2
        i_a = 4'b1111; i_b = 4'b0001; i_cin = 0;
        #10;
        $display("%0dns\t%b\t%b\t%b\t|\t%b\t%b", $time, i_a, i_b, i_cin, o_sum, o_cout);

        // 테스트 케이스 3
        i_a = 4'b1111; i_b = 4'b0001; i_cin = 1;
        #10;
        $display("%0dns\t%b\t%b\t%b\t|\t%b\t%b", $time, i_a, i_b, i_cin, o_sum, o_cout);

        // 무작위 테스트 케이스 진행 (10회)
        $display("\nRunning randomized test cases...");
        repeat (10) begin
            i_a = $urandom_range(0, 15);
            i_b = $urandom_range(0, 15);
            i_cin = $urandom_range(0, 1);
            #10;
            $display("%0dns\t%b\t%b\t%b\t|\t%b\t%b", $time, i_a, i_b, i_cin, o_sum, o_cout);
        end

        $display("==================================================");
        $finish;
    end
      
endmodule
