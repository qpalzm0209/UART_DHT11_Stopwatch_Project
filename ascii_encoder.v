`timescale 1ns / 1ps

module ascii_encoder (
    input             clk,
    input             rst,
    input             baud,
    input             tx_ready,
    input             tx_busy,
    input             start_sig,
    input      [23:0] watch_time,
    output reg [7:0]  time_data,
    output reg        tx_start
);

    // FSM state
    reg  [3:0] c_state, n_state;
    localparam IDLE = 4'd0;
    localparam WAIT = 4'd1;
    localparam H10  = 4'd2;
    localparam H1   = 4'd3;
    localparam COL1 = 4'd4;
    localparam M10  = 4'd5;
    localparam M1   = 4'd6;
    localparam COL2 = 4'd7;
    localparam S10  = 4'd8;
    localparam S1   = 4'd9;
    localparam CR   = 4'd10;
    localparam LF   = 4'd11;

    wire [7:0] hour_1  = ({3'b0, watch_time[23:19]} % 10);
    wire [7:0] hour_10 = ({3'b0, watch_time[23:19]} / 10);
    wire [7:0] min_1   = ({2'b0, watch_time[18:13]} % 10);
    wire [7:0] min_10  = ({2'b0, watch_time[18:13]} / 10);
    wire [7:0] sec_1   = ({2'b0, watch_time[12:7 ]} % 10);
    wire [7:0] sec_10  = ({2'b0, watch_time[12:7 ]} / 10);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = c_state;
        case (c_state)
            IDLE: if (!tx_busy && start_sig) n_state = H10;
            H10:  if (tx_ready)              n_state = H1;
            H1:   if (tx_ready)              n_state = COL1;
            COL1: if (tx_ready)              n_state = M10;
            M10:  if (tx_ready)              n_state = M1;
            M1:   if (tx_ready)              n_state = COL2;
            COL2: if (tx_ready)              n_state = S10;
            S10:  if (tx_ready)              n_state = S1;
            S1:   if (tx_ready)              n_state = CR;
            CR:   if (tx_ready)              n_state = LF;
            LF:   if (tx_ready)              n_state = IDLE;
            default: n_state = IDLE;
        endcase
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            tx_start  <= 1'b0;
            time_data <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            if (!tx_busy) begin
                case (c_state)
                    H10: begin
                        time_data <= 8'd48 + hour_10;
                        tx_start  <= 1'b1;
                    end
                    H1: begin
                        time_data <= 8'd48 + hour_1;
                        tx_start  <= 1'b1;
                    end
                    COL1: begin
                        time_data <= 8'h3A;
                        tx_start  <= 1'b1;
                    end
                    M10: begin
                        time_data <= 8'd48 + min_10;
                        tx_start  <= 1'b1;
                    end
                    M1: begin
                        time_data <= 8'd48 + min_1;
                        tx_start  <= 1'b1;
                    end
                    COL2: begin
                        time_data <= 8'h3A;
                        tx_start  <= 1'b1;
                    end
                    S10: begin
                        time_data <= 8'd48 + sec_10;
                        tx_start  <= 1'b1;
                    end
                    S1: begin
                        time_data <= 8'd48 + sec_1;
                        tx_start  <= 1'b1;
                    end
                    CR: begin
                        time_data <= 8'h0D;
                        tx_start  <= 1'b1;
                    end
                    LF: begin
                        time_data <= 8'h0A;
                        tx_start  <= 1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
