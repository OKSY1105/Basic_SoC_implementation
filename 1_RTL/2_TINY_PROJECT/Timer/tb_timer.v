module tb_timer();

reg tb_clk;
reg tb_rst;

wire [5:0] tb_sec;
wire [5:0] tb_min;
wire [3:0] tb_hour;

digtimer dut(.clk(tb_clk),.rst(tb_rst),.o_sec(tb_sec),.o_min(tb_min),.o_hour(tb_hour));


initial begin
    tb_rst =1; tb_clk=0;
    #20;
    tb_rst=0;
    
    forever #5 tb_clk = ~tb_clk;
    

end

endmodule
