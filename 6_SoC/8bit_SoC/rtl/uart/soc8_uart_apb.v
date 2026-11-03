`timescale 1ns/1ps
// 8bit SoC UART peripheral: APB3 slave registers around uart_top, with an
// interrupt request output. Frame 8E1 (8 data bits, even parity, 1 stop).
//
//   HADDR  PADDR  name         access  function
//   FF00   F00    RX_DATA      R       pop one byte from the RX FIFO;
//                                      ERROR (PSLVERR) if it is empty
//   FF01   F01    TX_DATA      W       push one byte into the TX FIFO;
//                                      ERROR if it is full
//   FF02   F02    STATUS       R       [0] RX_VALID   RX FIFO not empty
//                                      [1] TX_FULL    TX FIFO full
//                                      [2] TX_BUSY    TX FIFO or shifter busy
//                                      [3] OVERRUN    RX byte lost (FIFO full)
//                                      [4] FRAME_ERR  stop bit was 0
//                                      [5] PARITY_ERR parity mismatch
//                                      [6] TX_EMPTY   TX FIFO empty
//   FF03   F03    ERROR_CLEAR  W       write 1 to bit 3/4/5 clears that flag
//   FF04   F04    IRQ_EN       R/W     [0] RX_VALID [1] TX_EMPTY [2] any error
//
// - PREADY is always 1 (no wait states). A wrong direction (writing a
//   read-only register, reading a write-only one) or another PADDR gets
//   PSLVERR with no side effect.
// - Side effects happen once, in the ACCESS cycle of a successful transfer:
//   RX pop, TX push, flag clear, IRQ_EN update.
// - o_irq = registered (RX_VALID & EN0) | (TX_EMPTY & EN1) |
//   ((OVERRUN | FRAME_ERR | PARITY_ERR) & EN2). Level: it stays high until
//   the cause is handled (RX read, TX filled or EN1 cleared, flags cleared).
//   It follows the status with one clock of delay.
// - Reset: FIFOs and flags empty, IRQ_EN = 0, o_irq = 0.
module soc8_uart_apb #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115200,
    parameter FIFO_DEPTH  = 16
) (
    input  wire        i_clk,
    input  wire        i_rstn,
    // APB3 slave
    input  wire        i_psel,
    input  wire        i_penable,
    input  wire [11:0] i_paddr,
    input  wire        i_pwrite,
    input  wire [7:0]  i_pwdata,
    output reg  [7:0]  o_prdata,
    output wire        o_pready,
    output wire        o_pslverr,
    // Interrupt request (level, active high)
    output reg         o_irq,
    // UART pins
    output wire        o_uart_txd,
    input  wire        i_uart_rxd
);
    localparam [11:0] A_RX = 12'hF00, A_TX = 12'hF01, A_STATUS = 12'hF02,
                      A_ERRCLR = 12'hF03, A_IRQEN = 12'hF04;

    wire [7:0] w_rhr_rdata;
    wire w_dr, w_thre, w_temt, w_fe, w_pe, w_oe, w_tx_full, w_rx_full;
    reg  [2:0] r_irq_en;

    // ACCESS cycle; with PREADY always 1 it is the last cycle of the transfer.
    wire w_access = i_psel && i_penable;
    wire w_rd = w_access && !i_pwrite;
    wire w_wr = w_access && i_pwrite;

    wire w_err =
        (i_paddr == A_RX)     ? (i_pwrite || !w_dr) :
        (i_paddr == A_TX)     ? (!i_pwrite || w_tx_full) :
        (i_paddr == A_STATUS) ? i_pwrite :
        (i_paddr == A_ERRCLR) ? !i_pwrite :
        (i_paddr == A_IRQEN)  ? 1'b0 : 1'b1;

    wire       w_rhr_re = w_rd && (i_paddr == A_RX) && !w_err;
    wire       w_thr_we = w_wr && (i_paddr == A_TX) && !w_err;
    wire [2:0] w_lsr_clr = (w_wr && (i_paddr == A_ERRCLR)) ? i_pwdata[5:3] : 3'b000;

    wire [7:0] w_status = {1'b0, w_thre, w_pe, w_fe, w_oe, !w_temt, w_tx_full, w_dr};

    assign o_pready = 1'b1;
    assign o_pslverr = w_access && w_err;

    always @* begin
        case (i_paddr)
            A_RX:     o_prdata = w_rhr_rdata;
            A_STATUS: o_prdata = w_status;
            A_IRQEN:  o_prdata = {5'b00000, r_irq_en};
            default:  o_prdata = 8'h00;
        endcase
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_irq_en <= 3'b000; o_irq <= 1'b0;
        end else begin
            if (w_wr && (i_paddr == A_IRQEN)) r_irq_en <= i_pwdata[2:0];
            o_irq <= (w_dr && r_irq_en[0]) || (w_thre && r_irq_en[1]) ||
                     ((w_oe || w_fe || w_pe) && r_irq_en[2]);
        end
    end

    uart_top #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE),
        .DATA_BIT    (8),
        .FIFO_DEPTH  (FIFO_DEPTH)
    ) u_uart (
        .i_clk          (i_clk),
        .i_rst_n        (i_rstn),
        .o_uart_txd     (o_uart_txd),
        .i_uart_rxd     (i_uart_rxd),
        .i_thr_we       (w_thr_we),
        .i_thr_wdata    (i_pwdata),
        .i_rhr_re       (w_rhr_re),
        .o_rhr_rdata    (w_rhr_rdata),
        .o_lsr_dr       (w_dr),
        .o_lsr_thre     (w_thre),
        .o_lsr_temt     (w_temt),
        .o_lsr_fe       (w_fe),
        .o_lsr_pe       (w_pe),
        .o_lsr_oe       (w_oe),
        .i_lsr_clr      (w_lsr_clr),
        .o_tx_fifo_full (w_tx_full),
        .o_rx_fifo_full (w_rx_full)
    );
endmodule
