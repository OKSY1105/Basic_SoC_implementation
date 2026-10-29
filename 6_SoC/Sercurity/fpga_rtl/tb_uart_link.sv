`timescale 1ns/1ps
module tb_uart_link;
  localparam CPB=8;
  reg clk=0;
  always #10 clk=~clk;
  reg [3:0] sw=0;
  reg echo=0;
  reg rx=1;
  wire trig, tx, buzzer, motor_nsleep;
  wire [3:0] led;
  security_top #(.CLKS_PER_US(1),.CLKS_PER_2MS(40),.CLKS_PER_50MS(10000),
    .CLKS_PER_1S(200000),.DEBOUNCE_CYCLES(4),.CLKS_PER_BIT(CPB)) dut(
    .clk(clk),.pb_key(2'b00),.sw(sw),.touch_key(4'b0000),.sonar_echo(echo),
    .sonar_trig(trig),.uart_rx(rx),.uart_tx(tx),.led(led),.buzzer(buzzer),.motor_nsleep(motor_nsleep));
  initial forever begin
    @(negedge trig);
    repeat(10) @(negedge clk);
    echo=1;
    repeat(12*58+2) @(negedge clk);
    echo=0;
  end
  task automatic send_byte(input [7:0] value);
    integer i;
    begin
      @(negedge clk); rx=0; repeat(CPB) @(negedge clk);
      for(i=0;i<8;i=i+1) begin rx=value[i]; repeat(CPB) @(negedge clk); end
      rx=1; repeat(CPB) @(negedge clk);
    end
  endtask
  task automatic send_command(input [31:0] command, input bit bad_crc);
    reg [7:0] crc;
    begin
      crc=8'h02 ^ 8'h04 ^ command[31:24] ^ command[23:16] ^ command[15:8] ^ command[7:0];
      send_byte(8'haa);send_byte(2);send_byte(4);
      send_byte(command[31:24]);send_byte(command[23:16]);send_byte(command[15:8]);send_byte(command[7:0]);
      send_byte(bad_crc ? (crc ^ 8'hff) : crc);
      repeat(15000) @(negedge clk);
    end
  endtask
  integer frames=0, crc_errors=0, ack_count=0, pw_ok=0, err_count=0;
  integer dist_count=0, th_count=0, alarm_count=0, last_dist=-1, last_th=-1, last_alarm=-1;
  reg [7:0] b, typ, len, crc;
  reg [223:0] payload;
  integer state=0, idx=0, j;
  initial forever begin
    @(negedge tx); #(CPB*30);
    for(j=0;j<8;j=j+1) begin b[j]=tx; #(CPB*20); end
    if(tx !== 1) $fatal(1,"Invalid UART stop bit");
    case(state)
      0: if(b==8'haa) state=1;
      1: begin typ=b;crc=b;state=2;end
      2: begin len=b;crc=crc^b;payload=0;idx=0;state=(b==0)?4:3;end
      3: begin payload=(payload<<8)|b;crc=crc^b;idx=idx+1;if(idx==len)state=4;end
      4: begin
        if(crc!==b) crc_errors=crc_errors+1;
        else begin
          frames=frames+1;
          $display("FRAME type=%0d payload=%0s",typ,payload);
          if(typ==3 && payload=="OK")ack_count=ack_count+1;
          if(typ==4 && payload=="E:CRC")err_count=err_count+1;
          if(typ==1 && payload=="PW:OK_PC")pw_ok=pw_ok+1;
          if(typ==1 && len==13 && payload[103:32]=="Distance:") begin
            dist_count=dist_count+1;
            last_dist=(payload[31:24]-48)*1000+(payload[23:16]-48)*100+(payload[15:8]-48)*10+payload[7:0]-48;
          end
          if(typ==1 && len==14 && payload[111:32]=="Threshold:") begin
            th_count=th_count+1;
            last_th=(payload[31:24]-48)*1000+(payload[23:16]-48)*100+(payload[15:8]-48)*10+payload[7:0]-48;
          end
          if(typ==1 && len==7 && payload[55:8]=="Alarm:")begin alarm_count=alarm_count+1;last_alarm=payload[7:0]-48;end
        end
        state=0;
      end
    endcase
  end
  integer prev_th, prev_dist, prev_alarm, prev_ack;
  initial begin
    repeat(70000) @(negedge clk);
    prev_th=th_count;prev_dist=dist_count;prev_alarm=alarm_count;
    send_command("read",0);
    if(th_count<=prev_th || dist_count<=prev_dist || alarm_count<=prev_alarm ||
       last_th!=0 || last_dist!=12 || last_alarm!=0 || dut.alert_flag!==0)
      $fatal(1,"Connect-time snapshot failed");
    $display("PASS connect snapshot after boot: distance=12 threshold=0 alarm=0");
    sw=8;
    repeat(20000) @(negedge clk);
    if(dut.alert_flag!==1 || motor_nsleep!==1) $fatal(1,"Alarm trigger failed");
    send_command("read",0);
    if(last_th!=25 || last_dist!=12 || last_alarm!=1 || dut.alert_flag!==1)
      $fatal(1,"Read disturbed active alarm or wrong state");
    prev_ack=ack_count;
    send_command("stop",1);
    if(dut.alert_flag!==1 || err_count<1 || ack_count!=prev_ack) $fatal(1,"Bad CRC incorrectly stopped alarm");
    send_command("STOP",0);
    if(dut.alert_flag!==0 || led!==0 || buzzer!==0 || motor_nsleep!==0 || pw_ok<1)
      $fatal(1,"Confirmed STOP did not deactivate physical alarm outputs");
    send_command("READ",0);
    if(last_th!=25 || last_dist!=12 || last_alarm!=0) $fatal(1,"Post-STOP snapshot incorrect");
    repeat(500000) @(negedge clk);
    if(dut.alert_flag!==0 || motor_nsleep!==0 || !dut.disarm_hold) $fatal(1,"STOP retriggered with obstacle still present");
    if(crc_errors!=0) $fatal(1,"TX CRC errors");
    $display("UART_LINK_REGRESSION_PASS frames=%0d ack=%0d stop_confirm=%0d crc_errors=%0d",frames,ack_count,pw_ok,crc_errors);
    $finish;
  end
  initial begin #40000000; $fatal(1,"Timed out");end
endmodule
