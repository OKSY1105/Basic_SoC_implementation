module second(
clk,
rst,
sec
);
input clk, rst;
reg [19:0]cnt = 0;

output [5:0]sec;
reg [5:0] sec; 

always@(posedge clk or negedge rst)begin
    if(!rst) begin
        cnt <=0;
        sec <=0;
    end
    
    else begin 
        if(cnt >=99999) begin
            cnt <= 0;
            if (sec >= 59)sec <= 0;
            else sec <= sec+1;
            
            end
        
        else cnt <=cnt +1;
             
    end
end

endmodule

module minute(
clk,
rst,
sec,
min
 );
input clk, rst;
input [5:0]sec; 
reg [5:0] pre_sec;

output [5:0] min;
reg [5:0] min=0;

always @(posedge clk or negedge rst)begin
    if(!rst)begin
    pre_sec <=0;
    min <=0 ; 
    end
    else begin
        pre_sec <= sec;
        if (pre_sec == 59 && sec == 0) begin
            if(min >=59)min<= 0;
            else min<= min+1;
        end
    end
end

endmodule

module hour(
clk,
rst,
min,
hour
 );
input clk, rst; 
input wire [5:0]min; 
reg [5:0] pre_min;

output [3:0] hour;
reg [3:0] hour=0;

always @(posedge clk or negedge rst)begin
    if(!rst)begin
    hour <=0;
    pre_min <=0;
    end
    else begin
        pre_min<=min;
        
        if (pre_min == 59 && min ==0) begin
            if (hour >=11) hour <= 0;
            else hour<= hour+1; 
        
            end
     end
end

endmodule

module seven_seg(
input wire [3:0] num,
output reg [7:0] seven_seg 
);

    always @(num) begin
        case(num)
            4'b0000 : seven_seg = 8'b11111100;
            4'b0001 : seven_seg = 8'b01100000;
            4'b0010 : seven_seg = 8'b11011010;
            4'b0011 : seven_seg = 8'b11110010;
            4'b0100 : seven_seg = 8'b01100110;
            4'b0101 : seven_seg = 8'b10110110;
            4'b0110 : seven_seg = 8'b10111110;
            4'b0111 : seven_seg = 8'b11100000;
            4'b1000 : seven_seg = 8'b11111110;
            4'b1001 : seven_seg = 8'b11110110;
             default: seven_seg = 8'b11111111;
        endcase

    end

endmodule

module digit_ctrl(
    input clk,         
    input rst,              
    input [5:0] value,      
    output reg [7:0] fnd_data, 
    output reg [1:0] fnd_sel   
);

    wire [3:0] tens; 
    wire [3:0] ones; 
    wire [7:0] out_tens;
    wire [7:0] out_ones;

    
    assign tens = value / 10;
    assign ones = value % 10;

    
    seven_seg dec_tens ( .num(tens), .seven_seg(out_tens) );
    seven_seg dec_ones ( .num(ones), .seven_seg(out_ones) );

    
    reg toggle;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            toggle <= 1'b0;
            fnd_data <= 8'b0;
            fnd_sel <= 2'b00; 
        end else begin
            toggle <= ~toggle; 
            
            if (toggle == 1'b0) begin
                fnd_data <= out_ones; 
                fnd_sel  <= 2'b01;    
            end else begin
                fnd_data <= out_tens;
                fnd_sel  <= 2'b10;    
            end
        end
    end
endmodule

module digtimer(input rst,
                input clk,
                 output [5:0] o_sec,
                 output [5:0] o_min,
                 output [3:0] o_hour,
                 output [7:0] seg1_data, 
                 output [1:0] seg1_sel,  
                 output [7:0] seg2_data, 
                 output [1:0] seg2_sel,   
                 output [7:0] seg3_data,  
                 output [1:0] seg3_sel    
);

    wire [5:0] w_sec;
    wire [5:0] w_min;
    wire [3:0] w_hour;
 
    second ut_sec(.clk(clk), .rst(rst), .sec(w_sec));
    minute ut_min(.clk(clk), .rst(rst),  .sec(w_sec), .min(w_min));
    hour ut_hour(.clk(clk), .rst(rst), .min(w_min), .hour(w_hour));
    
    assign o_sec =w_sec;
    assign o_min =w_min;
    assign o_hour =w_hour;
    
    digit_ctrl ctrl_sec(.clk(clk),
               .rst(rst), 
               .value(o_sec),
               .fnd_data(seg3_data),
               .fnd_sel(seg3_sel)   
    ); 
    
    digit_ctrl ctrl_min(.clk(clk),
               .rst(rst), 
               .value(o_min),
               .fnd_data(seg2_data),
               .fnd_sel(seg2_sel)   
    );
    
    digit_ctrl ctrl_hour(.clk(clk),
               .rst(rst), 
               .value({2'b00, o_hour}),
               .fnd_data(seg1_data),
               .fnd_sel(seg1_sel)   
    );


endmodule
