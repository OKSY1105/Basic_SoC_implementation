`timescale 1ns / 1ps
module testbench;

wire [1:0]     i_add_a;
wire [1:0]     i_add_b;
wire [1:0]     i_add_c;
wire [1:0]     i_add_d;
wire           i_add_sub_sel;
wire [7:0]     o_final_cal_out;
reg [8:0]      cnt;
integer file;

 
  module_top u_module_top (
    .i_add_a         ( i_add_a         ),
    .i_add_b         ( i_add_b         ),
    .i_add_c         ( i_add_c         ),
    .i_add_d         ( i_add_d         ),
    .i_add_sub_sel   ( i_add_sub_sel   ),
    .o_final_cal_out ( o_final_cal_out )
  );

 
  assign i_add_sub_sel = cnt[0];
  assign i_add_a = cnt[2:1];
  assign i_add_b = cnt[4:3];
  assign i_add_c = cnt[6:5];
  assign i_add_d = cnt[8:7];

integer log_fd;
    integer step_idx;

    initial begin
        // 1. 로그 파일 생성
        log_fd = $fopen("arith_unit_sim.log", "w");
        if (!log_fd) begin
            $display("[FATAL] Unable to open log file.");
            $finish;
        end

        // 2. 초기화
        cnt = 0;
        #10;

        $display("--------------------------------------------------------------------------------");
        $display("[SIM START] Multi-Operand Arithmetic Verification");
        $display("--------------------------------------------------------------------------------");

        // 3. 루프 기반 자극 인가 및 지연 후 정형화 로깅
        for (step_idx = 0; step_idx < 512; step_idx = step_idx + 1) begin
            cnt = step_idx;
            #10; // 연산 안정화 시간 확보

            // 콘솔 및 파일 로그 기록 (포맷 표준화)
            $display("[STEP %03d] A: %4d | B: %4d | C: %4d | D: %4d | SEL: %b | OUT: 0x%08h",
                     step_idx, i_add_a, i_add_b, i_add_c, i_add_d, i_add_sub_sel, o_final_cal_out);
            $fdisplay(log_fd, "STEP=%03d, A=%d, B=%d, C=%d, D=%d, SEL=%b, OUT=0x%08h",
                      step_idx, i_add_a, i_add_b, i_add_c, i_add_d, i_add_sub_sel, o_final_cal_out);
        end

        #10;
        $display("--------------------------------------------------------------------------------");
        $display("[SIM END] Verification Finished Successfully.");
        $display("--------------------------------------------------------------------------------");

        // 4. 자원 해제 및 시뮬레이션 종료
        $fclose(log_fd);
        $finish;
    end

endmodule
