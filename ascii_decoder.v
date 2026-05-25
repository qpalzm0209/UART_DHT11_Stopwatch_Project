`timescale 1ns / 1ps

module ascii_decoder(
    input       clk,
    input       rst,
    input [7:0] key,
    output reg  btn_r,
    output reg  btn_l,
    output reg  btn_u,
    output reg  btn_d,
    output reg  s
);
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_r <= 1'b0;
            btn_l <= 1'b0;
            btn_u <= 1'b0;
            btn_d <= 1'b0;
            s     <= 1'b0;
        end else begin 
            btn_r <= (key == 8'h72);
            btn_l <= (key == 8'h6c);
            btn_u <= (key == 8'h75);
            btn_d <= (key == 8'h64);
            s     <= (key == 8'h73);
        end
    end

endmodule
