module ReLU  #(parameter inWidth=32, dataWidth=16,weightIntWidth=4) (
    input           clk,
    input signed [inWidth-1:0]   x,
    output  reg [dataWidth-1:0]  out
);
always @(posedge clk)
begin
    if($signed(x) >= 0)
    begin
        if(|x[inWidth-1-:weightIntWidth+1]) //over flow to sign bit of integer part
            out <= {(dataWidth){1'b1}}; //positive saturate (255)
        else
            out <= x[inWidth-1-weightIntWidth-:dataWidth];
    end
    else 
        out <= 0;      
end
endmodule