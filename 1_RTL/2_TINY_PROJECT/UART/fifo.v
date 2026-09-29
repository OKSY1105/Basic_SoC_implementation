module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    i_clk,
    i_rst_n,
    i_w_en,
    i_w_data,
    i_r_en,
    o_r_data,
    o_full,
    o_empty
);

input                  i_clk;
input                  i_rst_n;
input                  i_w_en;
input      [WIDTH-1:0] i_w_data;
input                  i_r_en;

output     [WIDTH-1:0] o_r_data;
output                 o_full;
output                 o_empty;

localparam PTR_ADR   = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
localparam CNT_WIDTH = $clog2(DEPTH);

// WIDTH-bit data x DEPTH entries
reg [WIDTH-1:0] mem [0:DEPTH-1];

// address pointers
reg [PTR_ADR-1:0] w_ptradr;
reg [PTR_ADR-1:0] r_ptradr;

// number of valid data currently stored in FIFO: 0 ~ DEPTH
reg [CNT_WIDTH:0] fifo_count;

assign o_full  = (fifo_count == DEPTH);
assign o_empty = (fifo_count == 0);

// Combinational read:
// If o_empty == 1, o_r_data must be ignored.
assign o_r_data = mem[r_ptradr];

wire w_write_ok;
wire w_read_ok;

assign w_write_ok = i_w_en && !o_full;
assign w_read_ok  = i_r_en && !o_empty;

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        w_ptradr   <= {PTR_ADR{1'b0}};
        r_ptradr   <= {PTR_ADR{1'b0}};
        fifo_count <= {CNT_WIDTH{1'b0}};
    end
    else begin
        case({w_write_ok, w_read_ok})
            // write only
            2'b10: begin
                mem[w_ptradr] <= i_w_data;

                if(w_ptradr == DEPTH-1)
                    w_ptradr <= {PTR_ADR{1'b0}};
                else
                    w_ptradr <= w_ptradr + 1'b1;

                fifo_count <= fifo_count + 1'b1;
            end

            // read only
            2'b01: begin
                if(r_ptradr == DEPTH-1)
                    r_ptradr <= {PTR_ADR{1'b0}};
                else
                    r_ptradr <= r_ptradr + 1'b1;

                fifo_count <= fifo_count - 1'b1;
            end

            // write and read at the same time
            2'b11: begin
                mem[w_ptradr] <= i_w_data;

                if(w_ptradr == DEPTH-1)
                    w_ptradr <= {PTR_ADR{1'b0}};
                else
                    w_ptradr <= w_ptradr + 1'b1;

                if(r_ptradr == DEPTH-1)
                    r_ptradr <= {PTR_ADR{1'b0}};
                else
                    r_ptradr <= r_ptradr + 1'b1;

                // one write + one read -> fifo_count does not change
            end

            default: begin
            end
        endcase
    end
end

endmodule
