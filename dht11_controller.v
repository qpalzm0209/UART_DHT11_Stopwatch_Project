`timescale 1ns / 1ps

module dht11_controller (
    input             clk,
    input             reset,
    input             start,
    output     [7:0] humid_int,
    output     [7:0] humid_dec,
    output     [7:0] temp_int,
    output     [7:0] temp_dec,
    output            dht11_done,
    output            dht11_vaild,
    output reg [ 3:0] debug,
    inout             dhtio
);

    wire tick;

    tick_gen U_tick_gen (
        .clk  (clk),
        .reset(reset),
        .tick (tick)
    );

    // STATE
    parameter IDLE = 0, START = 1, WAIT = 2, SYNC_L = 3, SYNC_H = 4,
                DATA_SYNC = 5, DATA_C = 6, STOP = 7;
    reg [2:0] c_state, n_state;
    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;
    reg [5:0] bit_cnt_reg, bit_cnt_next;
    reg [39:0] data_reg, data_next;
    reg [15:0] humid_reg, humid_next, temp_reg, temp_next;

    // check sum
    wire [8:0] sum =
      data_reg[39:32] +
      data_reg[31:24] +
      data_reg[23:16] +
      data_reg[15:8];

    wire good = (data_reg[7:0] == sum[7:0]);

    // 18msec count
    reg [$clog2(1900)-1:0] tick_cnt_reg, tick_cnt_next;

    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;

    // output
    assign humid_int  = data_reg[39:32];
    assign humid_dec  = data_reg[31:24];
    assign temp_int   = data_reg[23:16];
    assign temp_dec   = data_reg[15:8];

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            dhtio_reg <= 1'b1;
            io_sel_reg <= 1'b1;
            tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
            humid_reg <= 0;
            temp_reg <= 0;
            data_reg <= 0;
            data_next <= 0;
            // sum_next <= 0;
        end else begin
            c_state <= n_state;
            dhtio_reg <= dhtio_next;
            io_sel_reg <= io_sel_next;
            tick_cnt_reg <= tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            humid_reg <= humid_next;
            temp_reg <= temp_next;
            data_reg <= data_next;
            // sum_reg <= sum_next;
        end
    end

    always @(*) begin
        n_state       = c_state;
        tick_cnt_next = tick_cnt_reg;
        dhtio_next    = dhtio_reg;
        io_sel_next   = io_sel_reg;
        bit_cnt_next  = bit_cnt_reg;
        // sum_next      = sum_reg;
        case (c_state)
            IDLE: begin
                debug = 0;
                if (start) begin
                    tick_cnt_next = 0;
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                debug = 1;
                dhtio_next = 1'b1;
                if (tick) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 30) begin
                        // for output to high-z
                        n_state = SYNC_L;
                        io_sel_next = 1'b0;
                    end
                end
            end
            SYNC_L: begin
                debug = 2;
                if (tick) begin
                    if (dhtio == 1) begin
                        n_state = SYNC_H;
                    end
                end
            end
            SYNC_H: begin
                debug = 3;
                if (tick) begin
                    if (dhtio == 0) begin
                        n_state = DATA_SYNC;
                    end
                end
            end
            DATA_SYNC: begin
                debug = 4;
                if (tick) begin
                    if (dhtio == 1'b1) begin
                        tick_cnt_next = 0;  // HIGH 길이 측정 시작
                        n_state       = DATA_C;
                    end
                end
            end

            DATA_C: begin
                debug = 5;
                if (tick) begin
                    if (dhtio == 1) begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else if (dhtio == 0) begin
                        data_next[39 - bit_cnt_reg] = (tick_cnt_reg >= 40) ? 1'b1 : 1'b0;
                        tick_cnt_next = 0;
                        if (bit_cnt_reg == 39) begin
                            bit_cnt_next = 0;
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            n_state = DATA_SYNC;
                        end
                    end
                end
            end
            STOP: begin
                debug = 4'd6;

                if (tick) begin
                    if (good) begin
                        humid_next = data_reg[39:24];
                        temp_next  = data_reg[23:8];

                        if (dhtio == 1'b1) begin
                            tick_cnt_next = tick_cnt_reg + 1;
                            if (tick_cnt_reg >= 40) begin
                                dhtio_next    = 1'b1;
                                io_sel_next   = 1'b1;
                                tick_cnt_next = 0;
                                n_state       = IDLE;
                            end
                        end else begin
                            tick_cnt_next = 0;
                        end

                    end else begin
                        dhtio_next    = 1'b1;
                        io_sel_next   = 1'b1;
                        tick_cnt_next = 0;
                        bit_cnt_next  = 0;
                        n_state       = START;
                    end
                end
            end
        endcase
    end
endmodule


module tick_gen (
    input clk,
    input reset,
    output reg tick
);

    reg [$clog2(100)-1:0] cnt;  // 10Ms

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            cnt  <= 0;
            tick <= 0;
        end else begin
            cnt <= cnt + 1;
            if (cnt == 100 - 1) begin
                cnt  <= 0;
                tick <= 1;
            end else tick <= 0;
        end
    end
endmodule
