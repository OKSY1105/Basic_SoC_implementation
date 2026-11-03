`timescale 1ns/1ps
// AHB-Lite to APB3 bridge: one AHB-Lite slave port, one APB3 master port.
// With a single APB slave, PSEL drives it directly; with several APB slaves
// an APB decoder splits PSEL by PADDR.
//
// AHB side (slave, DATA_W-bit data, byte transfers only):
//   - An address phase is accepted when HSEL && HTRANS[1] && HREADY.
//     PADDR = HADDR[PADDR_W-1:0] and PWRITE are registered from it.
//   - HSIZE other than 000 gets a two-cycle ERROR without an APB transfer.
//   - HREADYOUT stays low through the APB transfer. The data phase ends in
//     the cycle after the APB ACCESS phase completes, with PRDATA and the
//     response registered: at least two wait cycles (SETUP, ACCESS).
//   - PSLVERR becomes a two-cycle AHB ERROR.
//   - HREADYOUT/HRESP/HRDATA come from registers only. IDLE gets zero-wait
//     OKAY.
// APB side (APB3, PCLK = HCLK):
//   - SETUP (PSEL=1, PENABLE=0) for one cycle, then ACCESS (PENABLE=1) until
//     PREADY. PREADY/PSLVERR/PRDATA are used only in ACCESS.
//   - PADDR, PWRITE and PWDATA stay stable through SETUP and ACCESS. PWDATA
//     is HWDATA: the AHB master holds HWDATA through the waited data phase,
//     and the bridge keeps HREADYOUT low until the APB transfer has ended.
//   - PSEL is low for at least one cycle between two transfers.
//
//   cycle   0          1           2 .. 2+w    3+w
//   AHB     address    data, wait  wait        data, HREADYOUT=1
//   APB     -          SETUP       ACCESS      -   (w = PREADY wait cycles)
module ahb_apb_bridge #(
    parameter integer HADDR_W = 16,
    parameter integer PADDR_W = 12,
    parameter integer DATA_W  = 8
) (
    input  wire               i_clk,
    input  wire               i_rstn,
    // AHB-Lite slave
    input  wire               i_hsel,
    input  wire [HADDR_W-1:0] i_haddr,
    input  wire [1:0]         i_htrans,
    input  wire               i_hwrite,
    input  wire [2:0]         i_hsize,
    input  wire [DATA_W-1:0]  i_hwdata,
    input  wire               i_hready,           // bus HREADY
    output wire               o_hreadyout,
    output wire               o_hresp,            // 1 = ERROR
    output wire [DATA_W-1:0]  o_hrdata,
    // APB3 master
    output wire               o_psel,
    output wire               o_penable,
    output wire [PADDR_W-1:0] o_paddr,
    output wire               o_pwrite,
    output wire [DATA_W-1:0]  o_pwdata,
    input  wire [DATA_W-1:0]  i_prdata,
    input  wire               i_pready,
    input  wire               i_pslverr
);
    localparam [2:0] ST_IDLE = 3'd0, ST_SETUP = 3'd1, ST_ACCESS = 3'd2,
                     ST_DONE = 3'd3, ST_ERR1 = 3'd4, ST_ERR2 = 3'd5;

    reg [2:0] r_state;
    reg [PADDR_W-1:0] r_paddr;
    reg r_pwrite;
    reg [DATA_W-1:0] r_hrdata;

    wire w_accept = i_hsel && i_htrans[1] && i_hready;
    wire w_size_ok = (i_hsize == 3'b000);

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_state <= ST_IDLE;
            r_paddr <= {PADDR_W{1'b0}}; r_pwrite <= 1'b0; r_hrdata <= {DATA_W{1'b0}};
        end else begin
            case (r_state)
                ST_SETUP: r_state <= ST_ACCESS;
                ST_ACCESS: if (i_pready) begin
                    r_state <= i_pslverr ? ST_ERR1 : ST_DONE;
                    r_hrdata <= i_prdata;
                end
                ST_ERR1: r_state <= ST_ERR2;
                // IDLE, DONE, ERR2: no data phase in progress, or the last
                // cycle of one. A new address phase is taken when HREADY is high.
                default: if (i_hready) begin
                    if (w_accept && w_size_ok) begin
                        r_state <= ST_SETUP;
                        r_paddr <= i_haddr[PADDR_W-1:0]; r_pwrite <= i_hwrite;
                    end else if (w_accept) begin
                        r_state <= ST_ERR1;
                    end else begin
                        r_state <= ST_IDLE;
                    end
                end
            endcase
        end
    end

    assign o_hreadyout = (r_state == ST_IDLE) || (r_state == ST_DONE) || (r_state == ST_ERR2);
    assign o_hresp = (r_state == ST_ERR1) || (r_state == ST_ERR2);
    assign o_hrdata = r_hrdata;
    assign o_psel = (r_state == ST_SETUP) || (r_state == ST_ACCESS);
    assign o_penable = (r_state == ST_ACCESS);
    assign o_paddr = r_paddr;
    assign o_pwrite = r_pwrite;
    assign o_pwdata = i_hwdata;
endmodule
