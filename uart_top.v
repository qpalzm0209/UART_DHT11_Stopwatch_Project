`timescale 1ns / 1ps

module uart_top (
    input clk,
    input rst,
    input [15:0] sw,
    input btn_r,
    input btn_l,
    input btn_u,
    input btn_d,
    input uart_rx,
    inout dht11_io,
    output uart_tx,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data;
    wire uart_btn_r, uart_btn_l, uart_btn_u, uart_btn_d, uart_s;
    wire w_tx_done, w_tx_busy, w_tx_start;
    wire [7:0] w_time_data;
    wire [7:0] w_humid_int, w_humid_dec, w_temp_int, w_temp_dec;
    wire w_dht11_done, w_dht11_vaild;
    wire [3:0] w_dht11_debug;

    top_stopwatch_watch U_WATCH_TOP(
        .clk        (clk),
        .reset      (rst),
        .sw         (sw[15:0]),         
        .btn_r      (btn_r),      // i_run_stop
        .btn_l      (btn_l),      // i_clear
        .btn_u      (btn_u),
        .btn_d      (btn_d),
        .uart_btn_r (uart_btn_r),
        .uart_btn_l (uart_btn_l),
        .uart_btn_u (uart_btn_u),
        .uart_btn_d (uart_btn_d),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data),
        .tx_ready   (w_tx_done),
        .tx_busy    (w_tx_busy),
        .start_sig  (uart_s),
        .time_data  (w_time_data),
        .tx_start   (w_tx_start)
    );

    ascii_decoder U_ASCII_DECODER(
        .clk    (clk),
        .rst    (rst),
        .key    (w_rx_data),
        .btn_r  (uart_btn_r),
        .btn_l  (uart_btn_l),
        .btn_u  (uart_btn_u),
        .btn_d  (uart_btn_d),
        .s      (uart_s)
    );

    dht11_controller U_DHT11_CONTROLLER (
        .clk        (clk),
        .reset      (rst),
        .start      (uart_s),
        .humid_int  (w_humid_int),
        .humid_dec  (w_humid_dec),
        .temp_int   (w_temp_int),
        .temp_dec   (w_temp_dec),
        .dht11_done (w_dht11_done),
        .dht11_vaild(w_dht11_vaild),
        .debug      (w_dht11_debug),
        .dhtio      (dht11_io)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .b_tick(w_b_tick),
        .tx_data(w_time_data),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .uart_tx(uart_tx)
    );
    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );
endmodule
