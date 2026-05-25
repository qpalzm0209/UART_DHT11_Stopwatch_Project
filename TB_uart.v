`timescale 1ns / 1ps

module tb_uart_loop_back ();

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000 / BAUD) * 10;  //104_160 한clk가 10ns니까 *10

    reg clk, reset, rx;
    wire tx;
    reg [7:0] test_data;
    integer i = 0, j = 0;


    uart_top dut (
        .clk(clk),
        .reset(reset),
        .uart_rx(rx),
        .uart_tx(tx)
    );

    always #5 clk = ~clk;

    task uart_sender();
        begin
            // uart test pattern
            //stat
            rx = 0;
            #(BAUD_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = test_data[i];
                #(BAUD_PERIOD);
            end

            //stop
            rx = 1'b1;
            #(BAUD_PERIOD);
        end
    endtask

    initial begin
        #0;
        clk = 0;
        reset = 1;
        rx = 1'b1;
        test_data = 8'h31;  //ascii '1'
        repeat (5) @(posedge clk);
        reset = 1'b0;

        //    for (j = 0; j < 10; j = j + 1) begin
        //        test_data = 8'h30 + j;
        //        uart_sender();
        //    end
        repeat (5) @(posedge clk);

        uart_sender();

        // hold time for uart tx output   
        for (j = 0; j < 12; j = j + 1) begin
            #(BAUD_PERIOD);
        end
        $stop;

    end
endmodule

