module zybo_uart_top #(
    parameter CLK_FREQ_HZ = 125_000_000,
    parameter BAUD_RATE   = 115200,
    parameter DATA_BIT    = 8,
    parameter FIFO_DEPTH  = 16
)(
    i_clk,

    i_btn_send,
    i_btn_reset,

    o_uart_txd,
    i_uart_rxd,

    o_led
);


// ============================================================
// PORT
// ============================================================

input                   i_clk;

input                   i_btn_send;
input                   i_btn_reset;

output                  o_uart_txd;
input                   i_uart_rxd;

output [3:0]            o_led;


// ============================================================
// RESET
// ============================================================

wire w_rst_n;

assign w_rst_n = ~i_btn_reset;


// ============================================================
// BUTTON SYNCHRONIZER
// ============================================================

reg r_btn_ff1;
reg r_btn_ff2;
reg r_btn_prev;

wire w_btn_rise;


assign w_btn_rise =
    r_btn_ff2 &
    ~r_btn_prev;


always @(posedge i_clk or negedge w_rst_n) begin

    if(!w_rst_n) begin

        r_btn_ff1  <= 1'b0;
        r_btn_ff2  <= 1'b0;
        r_btn_prev <= 1'b0;

    end

    else begin

        r_btn_ff1 <= i_btn_send;

        r_btn_ff2 <= r_btn_ff1;

        r_btn_prev <= r_btn_ff2;

    end

end


// ============================================================
// UART TOP 연결 신호
// ============================================================

reg                    r_thr_we;
reg [DATA_BIT-1:0]     r_thr_wdata;

reg                    r_rhr_re;

wire [DATA_BIT-1:0]    w_rhr_rdata;


wire w_lsr_dr;

wire w_lsr_thre;
wire w_lsr_temt;

wire w_lsr_fe;
wire w_lsr_pe;
wire w_lsr_oe;

wire w_tx_fifo_full;
wire w_rx_fifo_full;


// ============================================================
// 기존 UART TOP
// ============================================================

uart_top #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .BAUD_RATE   (BAUD_RATE),
    .DATA_BIT    (DATA_BIT),
    .FIFO_DEPTH  (FIFO_DEPTH)
)
u_uart_top (
    .i_clk          (i_clk),
    .i_rst_n        (w_rst_n),

    .o_uart_txd     (o_uart_txd),
    .i_uart_rxd     (i_uart_rxd),

    .i_thr_we       (r_thr_we),
    .i_thr_wdata    (r_thr_wdata),

    .i_rhr_re       (r_rhr_re),
    .o_rhr_rdata    (w_rhr_rdata),

    .o_lsr_dr       (w_lsr_dr),

    .o_lsr_thre     (w_lsr_thre),
    .o_lsr_temt     (w_lsr_temt),

    .o_lsr_fe       (w_lsr_fe),
    .o_lsr_pe       (w_lsr_pe),
    .o_lsr_oe       (w_lsr_oe),

    .o_tx_fifo_full (w_tx_fifo_full),
    .o_rx_fifo_full (w_rx_fifo_full)
);


// ============================================================
// TEST DATA
// ============================================================

localparam [DATA_BIT-1:0]
    TEST_DATA = 8'h55;


// ============================================================
// BTN -> TX
// ============================================================

reg r_send_pending;
reg r_tx_sent;


always @(posedge i_clk or negedge w_rst_n) begin

    if(!w_rst_n) begin

        r_thr_we       <= 1'b0;

        r_thr_wdata    <= TEST_DATA;

        r_send_pending <= 1'b0;

        r_tx_sent      <= 1'b0;

    end

    else begin

        // write enable은 기본 0
        r_thr_we <= 1'b0;


        // 버튼 눌림
        if(w_btn_rise) begin

            r_send_pending <= 1'b1;

            r_tx_sent <= 1'b0;

        end


        // FIFO에 자리가 있으면
        // 0x55 write
        if(r_send_pending &&
           !w_tx_fifo_full) begin

            r_thr_wdata <= TEST_DATA;

            r_thr_we <= 1'b1;

            r_send_pending <= 1'b0;

            r_tx_sent <= 1'b1;

        end

    end

end


// ============================================================
// RX CHECK
// ============================================================

reg r_rx_ok;
reg r_error;


always @(posedge i_clk or negedge w_rst_n) begin

    if(!w_rst_n) begin

        r_rhr_re <= 1'b0;

        r_rx_ok <= 1'b0;

        r_error <= 1'b0;

    end

    else begin

        r_rhr_re <= 1'b0;


        // RX FIFO에 데이터 있음
        if(w_lsr_dr &&
           !r_rhr_re) begin


            // 0x55가 정상적으로 돌아왔는지 확인
            if(w_rhr_rdata == TEST_DATA) begin

                r_rx_ok <= 1'b1;

            end

            else begin

                r_error <= 1'b1;

            end


            // RX FIFO POP
            r_rhr_re <= 1'b1;

        end


        // UART ERROR
        if(w_lsr_fe ||
           w_lsr_pe ||
           w_lsr_oe) begin

            r_error <= 1'b1;

        end

    end

end


// ============================================================
// HEARTBEAT
// 125 MHz 기준 약 0.5초마다 toggle
// ============================================================

localparam integer HEARTBEAT_CYCLES =
    CLK_FREQ_HZ / 2;

localparam integer HEARTBEAT_WIDTH =
    $clog2(HEARTBEAT_CYCLES);


reg [HEARTBEAT_WIDTH-1:0]
    r_heartbeat_cnt;

reg r_heartbeat;


always @(posedge i_clk or negedge w_rst_n) begin

    if(!w_rst_n) begin

        r_heartbeat_cnt <= 0;

        r_heartbeat <= 1'b0;

    end

    else begin

        if(r_heartbeat_cnt ==
           HEARTBEAT_CYCLES - 1) begin

            r_heartbeat_cnt <= 0;

            r_heartbeat <=
                ~r_heartbeat;

        end

        else begin

            r_heartbeat_cnt <=
                r_heartbeat_cnt + 1'b1;

        end

    end

end


// ============================================================
// LED
// ============================================================
//
// LED0 : NUCLEO Echo 0x55 정상 수신
//
// LED1 : BTN을 눌러 TX FIFO에 0x55 write
//
// LED2 : RX data / UART ERROR
//
// LED3 : FPGA clock 정상 동작
// ============================================================

assign o_led[0] = r_rx_ok;

assign o_led[1] = r_tx_sent;

assign o_led[2] = r_error;

assign o_led[3] = r_heartbeat;


endmodule
