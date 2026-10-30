`timescale 1ns/1ps

module tb_uart_top;

parameter CLK_FREQ_HZ = 100_000_000;
parameter BAUD_RATE   = 115200;
parameter DATA_BIT    = 8;
parameter FIFO_DEPTH  = 16;

/*
 * 100 MHz clock -> 10 ns period
 */
localparam CLK_HALF_PERIOD = 5;

/*
 * UART bit time
 * 1 / 115200 sec = about 8680 ns
 */
localparam BIT_TIME_NS =
    1_000_000_000 / BAUD_RATE;


// ============================================================
// DUT interface
// ============================================================

reg                    i_clk;
reg                    i_rst_n;

wire                   o_uart_txd;
reg                    i_uart_rxd;

reg                    i_thr_we;
reg  [DATA_BIT-1:0]    i_thr_wdata;

reg                    i_rhr_re;
wire [DATA_BIT-1:0]    o_rhr_rdata;

wire                   o_lsr_dr;
wire                   o_lsr_thre;
wire                   o_lsr_temt;
wire                   o_lsr_fe;
wire                   o_lsr_pe;
wire                   o_lsr_oe;

wire                   o_tx_fifo_full;
wire                   o_rx_fifo_full;


// ============================================================
// Testbench check
// ============================================================

reg                    tb_error;
reg                    tb_done;

reg [DATA_BIT-1:0]      tb_expected_data;
reg [DATA_BIT-1:0]      tb_received_data;


// ============================================================
// DUT
// ============================================================

uart_top #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .BAUD_RATE   (BAUD_RATE),
    .DATA_BIT    (DATA_BIT),
    .FIFO_DEPTH  (FIFO_DEPTH)
)
u_uart_top (
    .i_clk          (i_clk),
    .i_rst_n        (i_rst_n),

    .o_uart_txd     (o_uart_txd),
    .i_uart_rxd     (i_uart_rxd),

    .i_thr_we       (i_thr_we),
    .i_thr_wdata    (i_thr_wdata),

    .i_rhr_re       (i_rhr_re),
    .o_rhr_rdata    (o_rhr_rdata),

    .o_lsr_dr       (o_lsr_dr),
    .o_lsr_thre     (o_lsr_thre),
    .o_lsr_temt     (o_lsr_temt),
    .o_lsr_fe       (o_lsr_fe),
    .o_lsr_pe       (o_lsr_pe),
    .o_lsr_oe       (o_lsr_oe),

    .o_tx_fifo_full (o_tx_fifo_full),
    .o_rx_fifo_full (o_rx_fifo_full)
);


// ============================================================
// Clock
// ============================================================

initial begin
    i_clk = 1'b0;
end

always #CLK_HALF_PERIOD
    i_clk = ~i_clk;


// ============================================================
// CPU -> UART TX FIFO
// ============================================================

task cpu_write_byte;

    input [DATA_BIT-1:0] data;

    begin

        while(o_tx_fifo_full)
            @(posedge i_clk);

        @(negedge i_clk);

        i_thr_wdata = data;
        i_thr_we    = 1'b1;

        @(negedge i_clk);

        i_thr_we = 1'b0;

    end

endtask


// ============================================================
// UART RX FIFO -> CPU
// ============================================================

task cpu_read_and_check;

    input [DATA_BIT-1:0] expected_data;

    begin

        wait(o_lsr_dr == 1'b1);

        tb_expected_data = expected_data;
        tb_received_data = o_rhr_rdata;

        if(o_rhr_rdata !== expected_data)
            tb_error = 1'b1;

        @(negedge i_clk);

        i_rhr_re = 1'b1;

        @(negedge i_clk);

        i_rhr_re = 1'b0;

        repeat(3)
            @(posedge i_clk);

    end

endtask


// ============================================================
// NUCLEO behavioral model
// ============================================================

reg [DATA_BIT-1:0] nucleo_rx_data;

reg nucleo_rx_parity;
reg nucleo_calc_parity;
reg nucleo_stop_bit;

integer nucleo_bit_index;


// ============================================================
// NUCLEO -> FPGA
// ============================================================

task nucleo_send_byte;

    input [DATA_BIT-1:0] data;

    integer i;

    reg parity_bit;

    begin

        parity_bit = ^data;


        // START
        i_uart_rxd = 1'b0;

        #(BIT_TIME_NS);


        // DATA
        for(i = 0;
            i < DATA_BIT;
            i = i + 1) begin

            i_uart_rxd = data[i];

            #(BIT_TIME_NS);

        end


        // EVEN PARITY
        i_uart_rxd = parity_bit;

        #(BIT_TIME_NS);


        // STOP
        i_uart_rxd = 1'b1;

        #(BIT_TIME_NS);

    end

endtask


// ============================================================
// FPGA TX -> NUCLEO RX -> Echo
// ============================================================

initial begin

    i_uart_rxd         = 1'b1;

    nucleo_rx_data     = 0;
    nucleo_rx_parity   = 1'b0;
    nucleo_calc_parity = 1'b0;
    nucleo_stop_bit    = 1'b1;


    forever begin

        // FPGA TX START bit
        @(negedge o_uart_txd);


        // START 가운데
        #(BIT_TIME_NS / 2);


        if(o_uart_txd == 1'b0) begin


            // D0 가운데로 이동
            #(BIT_TIME_NS);


            // DATA D0 ~ D7
            for(nucleo_bit_index = 0;
                nucleo_bit_index < DATA_BIT;
                nucleo_bit_index = nucleo_bit_index + 1) begin

                nucleo_rx_data[nucleo_bit_index]
                    = o_uart_txd;

                #(BIT_TIME_NS);

            end


            // PARITY
            nucleo_rx_parity
                = o_uart_txd;

            nucleo_calc_parity
                = ^nucleo_rx_data;


            #(BIT_TIME_NS);


            // STOP
            nucleo_stop_bit
                = o_uart_txd;


            #(BIT_TIME_NS / 2);


            if(nucleo_rx_parity
               !== nucleo_calc_parity)

                tb_error = 1'b1;


            if(nucleo_stop_bit
               !== 1'b1)

                tb_error = 1'b1;


            // 받은 데이터 Echo
            nucleo_send_byte(
                nucleo_rx_data
            );

        end

    end

end


// ============================================================
// Main Test
// ============================================================

initial begin

    i_rst_n = 1'b0;

    i_thr_we    = 1'b0;
    i_thr_wdata = 0;

    i_rhr_re = 1'b0;

    tb_error = 1'b0;
    tb_done  = 1'b0;

    tb_expected_data = 0;
    tb_received_data = 0;


    // RESET
    repeat(10)
        @(posedge i_clk);

    @(negedge i_clk);

    i_rst_n = 1'b1;

    repeat(10)
        @(posedge i_clk);


    // 0x55
    cpu_write_byte(8'h55);

    cpu_read_and_check(8'h55);


    // 0xA5
    cpu_write_byte(8'hA5);

    cpu_read_and_check(8'hA5);


    // 0x00
    cpu_write_byte(8'h00);

    cpu_read_and_check(8'h00);


    // 0xFF
    cpu_write_byte(8'hFF);

    cpu_read_and_check(8'hFF);


    wait(o_lsr_temt == 1'b1);


    repeat(20)
        @(posedge i_clk);


    tb_done = 1'b1;


    $stop;

end


// ============================================================
// Timeout
// ============================================================

initial begin

    #2_000_000;


    if(!tb_done) begin

        tb_error = 1'b1;

        $stop;

    end

end


endmodule
