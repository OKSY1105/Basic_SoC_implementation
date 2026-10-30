`timescale 1ns/1ps
`include "cpu8_isa.vh"
module tb_cpu8_alu;
    reg [7:0] a,b;
    reg [5:0] op;
    reg c;
    wire [7:0] result;
    wire [3:0] flags;
    cpu8_alu dut(.i_a(a),.i_b(b),.i_opcode(op),.i_carry(c),
                 .o_result(result),.o_flags(flags));
    integer ai,bi,ci,oi,total,signed_total,sa,sb,extra,cases=0;
    reg [7:0] expected;
    reg ec,ev;
    reg [3:0] ef;
    initial begin
        for(oi=0;oi<6;oi=oi+1)
        for(ai=0;ai<256;ai=ai+1)
        for(bi=0;bi<256;bi=bi+1)
        for(ci=0;ci<2;ci=ci+1) begin
            a=ai;b=bi;c=ci;
            sa=ai<128 ? ai : ai-256;
            sb=bi<128 ? bi : bi-256;
            case(oi)
                0:op=`CPU8_OP_ADD;
                1:op=`CPU8_OP_ADC;
                2:op=`CPU8_OP_SUB;
                3:op=`CPU8_OP_SBC;
                4:op=`CPU8_OP_CMP;
                5:op=`CPU8_OP_AND;
            endcase
            extra=0;ec=0;ev=0;
            if(oi<2) begin
                if(oi==1)extra=ci;
                total=ai+bi+extra;signed_total=sa+sb+extra;
                ec=total>255;ev=signed_total< -128 || signed_total>127;
            end else if(oi<5) begin
                if(oi==3)extra=1-ci;
                total=ai-bi-extra;signed_total=sa-sb-extra;
                ec=total>=0;ev=signed_total< -128 || signed_total>127;
            end else total=ai&bi;
            expected=total&255;
            ef={(expected==0),expected[7],ec,ev};
            #1;
            if(result!==expected || flags!==ef)
                $fatal(1,"ALU mismatch op=%h a=%h b=%h c=%b result=%h/%h flags=%h/%h",
                       op,a,b,c,result,expected,flags,ef);
            cases=cases+1;
        end
        $display("ALU_PASS %0d",cases);
        $finish;
    end
endmodule
