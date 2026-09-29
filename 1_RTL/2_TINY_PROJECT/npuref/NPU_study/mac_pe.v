module mac_pe #(
  parameter DATA_W = 8,
  parameter ACC_W  = 2*DATA_W
)(
  input                    clk,
  input                    rst_n,

  input                    clr,
  input                    en,

  input      [DATA_W-1:0]  a,
  input      [DATA_W-1:0]  b,

  output     [ACC_W-1:0]   mul,
  output     [ACC_W-1:0]   acc_sum
);

  reg [ACC_W-1:0] mul_reg;
  reg [ACC_W-1:0] acc_sum_reg;

  assign mul = mul_reg;
  assign acc_sum = acc_sum_reg;

  // Combinational Logic: Multiplier
  always @(*) begin
    mul_reg = a * b;
  end

  // Sequential Logic: Accumulator
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_sum_reg <= 0;
    end
    else begin
      if (clr) begin
        acc_sum_reg <= 0;
      end
      else if (en) begin
        acc_sum_reg <= acc_sum_reg + mul_reg;
      end
    end
  end

endmodule
