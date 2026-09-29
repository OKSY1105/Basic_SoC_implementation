module tb_interrupt;

reg [7:0] i_int_address;
reg i_int_ack;

wire [2:0] o_int_id;
wire o_int_req;


interrupt DUT (

.i_int_address(i_int_address),
.i_int_ack(i_int_ack),
.o_int_req(o_int_req),
.o_int_id(o_int_id)
);


initial begin
    $dumpfile("./interrupt.vcd") ;
    $dumpvars(0, tb_interrupt)   ;
end

initial begin

$monitor("Time=%0t | i_int_address=%b | i_int_ack=%b | o_int_id=%b | o_int_req=%b", 
            $time, i_int_address, i_int_ack, o_int_id, o_int_req);

    i_int_address = 8'b0000_000  ; 
    i_int_ack = 1'b0 ;      
                
    // apply stimulus
    #10 i_int_address = 8'b0000_0001  ;  
    #10 i_int_address = 8'b0010_0000  ;  
    #10 i_int_address = 8'b1000_0000  ;  
    #10 i_int_ack   = 1'b1 ;       
    #10 i_int_ack   = 1'b0 ;       
                                            
    #10 i_int_address = 8'b0100_0010;  
    #10 i_int_ack = 1'b1;       
    #10 i_int_ack = 1'b0;
    //                                                                 
     #10 i_int_address = 8'b0000_0000;  
                                                                                
     #20 $finish;             
end

endmodule
