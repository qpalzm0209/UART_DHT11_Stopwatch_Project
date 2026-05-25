`timescale 1ns / 1ps

module top_stopwatch_watch (
    input        clk,
    input        reset,
    input [15:0] sw,         // up/down
    input        btn_r,      // i_run_stop
    input        btn_l,      // i_clear
    input        btn_u,
    input        btn_d,
    input        uart_btn_r,
    input        uart_btn_l,
    input        uart_btn_u,
    input        uart_btn_d,
    input        tx_ready,
    input        start_sig,
    input        tx_busy,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [7:0] time_data,
    output       tx_start
);

    wire [13:0] w_counter;
    wire w_run_stop, w_clear, w_run_stop_t, w_clear_t,w_mode;
    wire o_btn_run_stop, o_btn_clear, o_btn_u, o_btn_d;
    wire [23:0] w_stopwatch_time;
    wire [23:0] w_watch_time;
    wire [7:0] w_fnd_data, w_fnd_data_t;
    wire [3:0] w_fnd_digit, w_fnd_digit_t;
    wire w_ad_hour, w_ad_min, w_ad_sec, w_sub_hour, w_sub_min, w_sub_sec;
    wire oo_btn_run_stop, oo_btn_clear, oo_btn_u, oo_btn_d;

    assign oo_btn_run_stop  = uart_btn_r | o_btn_run_stop;
    assign oo_btn_clear     = uart_btn_l | o_btn_clear;
    assign oo_btn_u         = uart_btn_u | o_btn_u;
    assign oo_btn_d         = uart_btn_d | o_btn_d;


    btn_debounce U_BD_RUNSTOP (
        .clk    (clk),
        .reset  (reset),
        .i_btn  (btn_r),
        .o_btn  (o_btn_run_stop)
    );
    btn_debounce U_BD_CLEAR (
        .clk    (clk),
        .reset  (reset),
        .i_btn  (btn_l),
        .o_btn  (o_btn_clear)
    );
    btn_debounce U_BD_BTN_U (
        .clk    (clk),
        .reset  (reset),
        .i_btn  (btn_u),
        .o_btn  (o_btn_u)
    );
    btn_debounce U_BD_BTN_D (
        .clk    (clk),
        .reset  (reset),
        .i_btn  (btn_d),
        .o_btn  (o_btn_d)
    );

    control_unit U_CONTROL_UNIT (
        .clk         (clk),
        .reset       (reset),
        .sw_1        (sw[1]),
        .i_mode      (sw[0]),
        .i_run_stop  (oo_btn_run_stop),
        .i_clear     (oo_btn_clear),
        .o_mode      (w_mode),
        .o_run_stop  (w_run_stop),
        .o_clear     (w_clear),
        .o_run_stop_t(w_run_stop_t),
        .o_clear_t   (w_clear_t)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk        (clk),
        .reset      (reset),
        .mode       (w_mode),
        .clear      (w_clear),
        .run_stop   (w_run_stop),
        .msec       (w_stopwatch_time[6:0]),
        .sec        (w_stopwatch_time[12:7]),
        .min        (w_stopwatch_time[18:13]),
        .hour       (w_stopwatch_time[23:19])
    );
    watch_datapath U_WATCH_DATAPATH (
        .clk            (clk),
        .reset          (reset),
        .t_clear        (w_clear_t),
        .t_run_stop     (w_run_stop_t),
        .btn_u          (oo_btn_u),
        .btn_d          (oo_btn_d),
        .sw_15          (sw[15]),
        .sw_14          (sw[14]),
        .sw_13          (sw[13]),
        .t_msec         (w_watch_time[6:0]),
        .t_sec          (w_watch_time[12:7]),
        .t_min          (w_watch_time[18:13]),
        .t_hour         (w_watch_time[23:19]) 
    );

    ascii_encoder U_ENCODER(
        .clk        (clk),
        .rst        (reset),
        .tx_ready   (tx_ready),
        .tx_busy    (tx_busy),
        .start_sig  (start_sig),
        .watch_time (w_watch_time),
        .time_data  (time_data),
        .tx_start   (tx_start)
    );

    fnd_controller U_FND_CNTL_0 (
        .clk        (clk),
        .reset      (reset),
        .sel_display(sw[2]),
        .fnd_in_data(w_stopwatch_time),
        .fnd_digit  (w_fnd_digit),
        .fnd_data   (w_fnd_data)
    );
    watch_fnd_controller U_FND_CNTL_1 (
        .clk          (clk),
        .reset        (reset),
        .sel_display  (sw[2]),
        .fnd_in_data  (w_watch_time),
        .fnd_digit_t  (w_fnd_digit_t),
        .fnd_data_t   (w_fnd_data_t)
    );
    mux_2x1_mode #(
        .IN_DATA(4),
        .OUT_DATA(4)
    ) U_MUX_DIGIT(
        .sel    (sw[1]),
        .i_sel0 (w_fnd_digit),
        .i_sel1 (w_fnd_digit_t),
        .o_mux  (fnd_digit)
    );
    mux_2x1_mode #(
        .IN_DATA(8),
        .OUT_DATA(8)
    ) U_MUX_DATA(
        .sel    (sw[1]),
        .i_sel0 (w_fnd_data),
        .i_sel1 (w_fnd_data_t),
        .o_mux  (fnd_data)
    );
endmodule

module control_unit(
        input   clk,
        input   reset,
        input   sw_1,
        input   i_mode,
        input   i_run_stop,
        input   i_clear,
        output  o_mode,
        output  reg o_run_stop,
        output  reg o_clear,
        output  reg o_run_stop_t,
        output  reg o_clear_t
    );

    localparam stop  = 2'b00;
    localparam run   = 2'b01;
    localparam clear = 2'b10;

    // reg variable
    reg [1:0]   current_st,   next_st;
    reg [1:0]   current_st_t, next_st_t;

    assign o_mode = i_mode;

    // ✅ 입력 게이팅(내부 신호만 추가, 기존 포트/변수명은 그대로)
    wire i_run_stop_sw = (sw_1 == 1'b0) ? i_run_stop : 1'b0;
    wire i_clear_sw    = (sw_1 == 1'b0) ? i_clear    : 1'b0;

    wire i_run_stop_tg = (sw_1 == 1'b1) ? i_run_stop : 1'b0;
    wire i_clear_tg    = (sw_1 == 1'b1) ? i_clear    : 1'b0;

    // state register SL (✅ 둘 다 항상 업데이트 = 백그라운드 진행)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st   <= stop;
            current_st_t <= stop;
        end else begin
            current_st   <= next_st;
            current_st_t <= next_st_t;
        end
    end

    // next CL (✅ 두 FSM 모두 항상 계산)
    always @(*) begin
        // 기본값
        next_st       = current_st;
        next_st_t     = current_st_t;

        o_run_stop    = 1'b0;
        o_clear       = 1'b0;
        o_run_stop_t  = 1'b0;
        o_clear_t     = 1'b0;

        // -------------------------
        // 스톱워치 FSM (항상 진행)
        // 버튼은 sw_1=0일 때만 반영(i_run_stop_sw / i_clear_sw)
        // -------------------------
        case (current_st)
            stop: begin
                if      (i_run_stop_sw) next_st = run;
                else if (i_clear_sw)    next_st = clear;
            end
            run: begin
                o_run_stop = 1'b1;
                if (i_run_stop_sw) next_st = stop;
            end
            clear: begin
                o_clear = 1'b1;
                next_st = stop;
            end
            default: next_st = stop;
        endcase

        // -------------------------
        // 시계 FSM (항상 진행)
        // 버튼은 sw_1=1일 때만 반영(i_run_stop_tg / i_clear_tg)
        // -------------------------
        case (current_st_t)
            stop: begin
                if      (i_run_stop_tg) next_st_t = run;
                else if (i_clear_tg)    next_st_t = clear;
            end
            run: begin
                o_run_stop_t = 1'b1;
                if (i_run_stop_tg) next_st_t = stop;
            end
            clear: begin
                o_clear_t = 1'b1;
                next_st_t = stop;
            end
            default: next_st_t = stop;
        endcase
    end

endmodule

module watch_datapath(
    input   clk,
    input   reset,
    input   t_clear,
    input   t_run_stop,
    input   btn_u,
    input   btn_d,
    input   sw_15,
    input   sw_14,
    input   sw_13,
    output  [6:0] t_msec,
    output  [5:0] t_sec,
    output  [5:0] t_min,
    output  [4:0] t_hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIME(24)
    ) hour_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_hour_tick),
        .mode       (1'b0),
        .clear      (t_clear),
        .run_stop   (t_run_stop),
        .btn_u      (btn_u),
        .btn_d      (btn_d),
        .sw         (sw_15),   
        .o_count    (t_hour),
        .o_tick     ()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIME(60)
    ) min_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_min_tick),
        .mode       (1'b0),
        .clear      (t_clear),
        .run_stop   (t_run_stop),
        .btn_u      (btn_u),
        .btn_d      (btn_d),
        .sw         (sw_14),
        .o_count    (t_min),
        .o_tick     (w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIME(60)
    ) sec_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_sec_tick),
        .mode       (1'b0),
        .clear      (t_clear),
        .run_stop   (t_run_stop),
        .btn_u      (btn_u),
        .btn_d      (btn_d),
        .sw         (sw_13),
        .o_count    (t_sec),
        .o_tick     (w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIME(100)
    ) msec_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_tick_100hz),
        .mode       (1'b0),
        .clear      (t_clear),
        .run_stop   (t_run_stop),
        .btn_u      (1'b0),
        .btn_d      (1'b0),
        .sw         (1'b0),
        .o_count    (t_msec),
        .o_tick     (w_sec_tick)
    );
    tick_gen_100hz U_tick_gne_100hz (
        .clk            (clk),
        .reset          (reset),
        .i_run_stop     (t_run_stop),
        .o_tick_100hz   (w_tick_100hz)
    );

endmodule

module stopwatch_datapath(
    input   clk,
    input   reset,
    input   mode,
    input   clear,
    input   run_stop,
    output  [6:0] msec,
    output  [5:0] sec,
    output  [5:0] min,
    output  [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIME(24)
    ) hour_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_hour_tick),
        .mode       (mode),
        .clear      (clear),
        .run_stop   (run_stop),
        .o_count    (hour),
        .o_tick     ()
    );


    // tick_counter #(
    //     .BIT_WIDTH(5),
    //     .TIME(24)
    // ) hour_counter(
    //     .clk        (clk),
    //     .reset      (reset),
    //     .i_tick     (w_hour_tick),
    //     .mode       (mode),   
    //     .clear      (clear),
    //     .run_stop   (run_stop),
    //     .btn_u      (1'b0),
    //     .btn_d      (1'b0),
    //     .sw         (1'b0),        
    //     .o_count    (hour),
    //     .o_tick     (1'b0)
    // );

    tick_counter #(
        .BIT_WIDTH(6),
        .TIME(60)
    ) min_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_min_tick),
        .mode       (mode),
        .clear      (clear),
        .run_stop   (run_stop),
        .o_count    (min),
        .o_tick     (w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIME(60)
    ) sec_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_sec_tick),
        .mode       (mode),
        .clear      (clear),
        .run_stop   (run_stop),
        .o_count    (sec),
        .o_tick     (w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIME(100)
    ) msec_counter(
        .clk        (clk),
        .reset      (reset),
        .i_tick     (w_tick_100hz),
        .mode       (mode),
        .clear      (clear),
        .run_stop   (run_stop),
        .o_count    (msec),
        .o_tick     (w_sec_tick)
    );
    tick_gen_100hz U_tick_gne_100hz (
        .clk            (clk),
        .reset          (reset),
        .i_run_stop     (run_stop),
        .o_tick_100hz   (w_tick_100hz)
    );

endmodule



module btn_debounce(
    input   clk,
    input   reset,
    input   i_btn,
    output  o_btn
);
    reg [7:0]   q_reg, q_next;
    wire debounce;

    always @(posedge clk, posedge reset) begin
        if (reset)  begin q_reg <= 0;       end
        else        begin q_reg <= q_next;  end
    end

    always @(*)     begin q_next = {i_btn, q_reg[7:1]}; end

    // debounce, 8input and
    assign debounce =& q_reg;

    reg edge_reg;
    //edge detection
    always@(posedge clk, posedge reset) begin
        if (reset)  begin edge_reg <= 1'b0;     end
        else        begin edge_reg <= debounce; end            
    end

    assign o_btn = debounce & (~edge_reg);

endmodule

module fnd_controller (
    input clk,
    input reset,
    input sel_display,
    input [23:0] fnd_in_data,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;
    wire [2:0] w_digit_sel;
    wire w_1khz;
    wire w_dot_onoff;
    
    //hour
    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    //min
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data (fnd_in_data[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );
    //sec
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );
    //msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );
    dot_onoff_comp U_DOT_COMP (
        .msec       (fnd_in_data[6:0]),
        .dot_onoff  (w_dot_onoff)
    );
    mux_8x1 U_MUX_HOUR_MIN (
        .sel           (w_digit_sel),
        .digit_1       (w_digit_min_1),
        .digit_10      (w_digit_min_10),
        .digit_100     (w_digit_hour_1),
        .digit_1000    (w_digit_hour_10),
        .digit_dot_1   (4'hf),
        .digit_dot_10  (4'hf),
        .digit_dot_100 ({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out       (w_mux_hour_min_out)
    );
    mux_8x1 U_MUX_SEC_MSEC (
        .sel           (w_digit_sel),
        .digit_1       (w_digit_msec_1),
        .digit_10      (w_digit_msec_10),
        .digit_100     (w_digit_sec_1),
        .digit_1000    (w_digit_sec_10),
        .digit_dot_1   (4'hf),
        .digit_dot_10  (4'hf),
        .digit_dot_100 ({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out       (w_mux_sec_msec_out)
    );
    mux_2x1 U_MUX_2x1 (
        .sel   (sel_display),
        .i_sel0(w_mux_sec_msec_out),
        .i_sel1(w_mux_hour_min_out),
        .o_mux (w_mux_2x1_out)
    );
    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1khz(w_1khz)
    );
    counter_8 U_COUNTER_8 (
        .clk      (w_1khz),
        .reset    (reset),
        .digit_sel(w_digit_sel)
    );
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_digit (fnd_digit)
    );
    bcd U_BCD (
        .bcd     (w_mux_2x1_out),
        .fnd_data(fnd_data)
    );

endmodule



///////////////////////////////////////////////////////////////////////


module bcd (
    input      [3:0] bcd,
    output reg [7:0] fnd_data
);
    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hC0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'hff;
            4'd11: fnd_data = 8'hff;
            4'd12: fnd_data = 8'hff;
            4'd13: fnd_data = 8'hff;
            4'd14: fnd_data = 8'h7f;
            4'd15: fnd_data = 8'hff;
            default: fnd_data = 8'hFF;
        endcase
    end
endmodule

module counter_8 (
    input        clk,
    input        reset,
    output [2:0] digit_sel
);
    reg [2:0] counter_r;

    assign digit_sel = counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
        end else begin
            counter_r <= counter_r + 1;
        end
    end
endmodule

module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_digit
);
    always @(*) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end
endmodule


module dot_onoff_comp (
    input [6:0] msec,
    output      dot_onoff 
);
    assign dot_onoff = (msec < 50);
endmodule

module digit_splitter #(parameter BIT_WIDTH = 7)(
    input   [BIT_WIDTH-1:0] in_data,
    output  [ 3:0]          digit_1,
    output  [ 3:0]          digit_10
);
    assign digit_1    = in_data % 10;
    assign digit_10   = (in_data / 10)  % 10;
endmodule

module clk_div (
    input      clk,
    input      reset,
    output reg o_1khz
);
    reg [$clog2(100_000):0] counter_r;  // log2(100_000) = 16

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz      <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r   <= 0;
                o_1khz      <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz      <= 1'b0;
            end
        end
    end

endmodule

module mux_2x1(
    input        sel,
    input  [3:0] i_sel0,
    input  [3:0] i_sel1,
    output [3:0] o_mux
);
    assign o_mux = (sel) ? i_sel1 : i_sel0;
endmodule

module mux_2x1_mode #(
    parameter integer IN_DATA = 7,
    parameter integer OUT_DATA = 100
)(
    input                sel,
    input  [IN_DATA-1:0] i_sel0,
    input  [IN_DATA-1:0] i_sel1,
    output [OUT_DATA-1:0] o_mux
);
    assign o_mux = (sel) ? i_sel1 : i_sel0;
endmodule

module mux_8x1 (
    input      [2:0] sel,
    input      [3:0] digit_1,
    input      [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    input      [3:0] digit_dot_1,
    input      [3:0] digit_dot_10,
    input      [3:0] digit_dot_100,
    input      [3:0] digit_dot_1000,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end
endmodule

module tick_counter #(
    parameter integer BIT_WIDTH = 7,
    parameter integer TIME      = 100
) (
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      mode,      // 0:UP, 1:DOWN 
    input                      clear,
    input                      run_stop,
    input                      btn_u,
    input                      btn_d,
    input                      sw,        
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);

    reg [BIT_WIDTH-1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    // state register
    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            counter_reg <= {BIT_WIDTH{1'b0}};
        end else begin
            counter_reg <= counter_next;
        end
    end

    // next-state + tick pulse
    always @(*) begin
        counter_next = counter_reg;
        o_tick       = 1'b0;

    // time up & down
        if (sw) begin
            if (btn_u && !btn_d) begin
                // UP 
                if (counter_reg == (TIME - 1))
                    counter_next = {BIT_WIDTH{1'b0}};
                else
                    counter_next = counter_reg + 1'b1;

            end else if (btn_d && !btn_u) begin
                // DOWN
                if (counter_reg == 0)
                    counter_next = TIME - 1;
                else
                    counter_next = counter_reg - 1'b1;
            end
        end

    // count clk
        else if (i_tick && run_stop) begin
            if (mode) begin
                // DOWN
                if (counter_reg == 0) begin
                    counter_next = TIME - 1;
                    o_tick       = 1'b1;
                end else begin
                    counter_next = counter_reg - 1'b1;
                end
            end else begin
                // UP
                if (counter_reg == (TIME - 1)) begin
                    counter_next = {BIT_WIDTH{1'b0}};
                    o_tick       = 1'b1;
                end else begin
                    counter_next = counter_reg + 1'b1;
                end
            end
        end
    end

endmodule

module watch_fnd_controller (
    input clk,
    input reset,
    input sel_display,
    input [23:0] fnd_in_data,
    output [3:0] fnd_digit_t,
    output [7:0] fnd_data_t
);
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;
    wire [2:0] w_digit_sel;
    wire w_1khz;
    wire w_dot_onoff;

    //hour
    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    //min
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data (fnd_in_data[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );
    //sec
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );
    //msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );
    dot_onoff_comp U_DOT_COMP (
        .msec       (fnd_in_data[6:0]),
        .dot_onoff  (w_dot_onoff)
    );
    mux_8x1 U_MUX_HOUR_MIN (
        .sel           (w_digit_sel),
        .digit_1       (w_digit_min_1),
        .digit_10      (w_digit_min_10),
        .digit_100     (w_digit_hour_1),
        .digit_1000    (w_digit_hour_10),
        .digit_dot_1   (4'hf),
        .digit_dot_10  (4'hf),
        .digit_dot_100 ({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out       (w_mux_hour_min_out)
    );
    mux_8x1 U_MUX_SEC_MSEC (
        .sel           (w_digit_sel),
        .digit_1       (w_digit_msec_1),
        .digit_10      (w_digit_msec_10),
        .digit_100     (w_digit_sec_1),
        .digit_1000    (w_digit_sec_10),
        .digit_dot_1   (4'hf),
        .digit_dot_10  (4'hf),
        .digit_dot_100 ({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out       (w_mux_sec_msec_out)
    );
    mux_2x1 U_MUX_2x1 (
        .sel   (sel_display),
        .i_sel0(w_mux_sec_msec_out),
        .i_sel1(w_mux_hour_min_out),
        .o_mux (w_mux_2x1_out)
    );
    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1khz(w_1khz)
    );
    counter_8 U_COUNTER_8 (
        .clk      (w_1khz),
        .reset    (reset),
        .digit_sel(w_digit_sel)
    );
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_digit (fnd_digit_t)        //
    );
    bcd U_BCD (
        .bcd     (w_mux_2x1_out),
        .fnd_data(fnd_data_t)           //
    );

endmodule

module tick_gen_100hz (
    input        clk,
    input        reset,
    input        i_run_stop,
    output reg   o_tick_100hz
);

    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter   <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter   <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end
    
endmodule
