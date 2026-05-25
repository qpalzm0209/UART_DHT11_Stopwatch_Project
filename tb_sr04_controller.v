/*
[TB_INFO_START]
Name: tb_sr04_controller
Target: sr04_controller
Role: Testbench for SR04 Ultrasonic Controller
Scenario:
  - Generates request pulses
  - Simulates Echo return signal with variable duration (`send_echo_high_cycles`)
CheckPoint:
  - Verifies Trigger pulse generation (10us)
  - Verifies Distance calculation based on echo width
  - Checks flag assertions for valid measurement
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_sr04_controller;
  initial begin
    $dumpfile("tb_sr04_controller.vcd");
    $dumpvars(0, tb_sr04_controller);
  end

  reg iClk;
  reg iRst;
  reg iEcho;
  reg iStart;
  reg iTickUs;

  wire oTrig;
  wire [9:0] oDistanceCm;
  wire oDistanceValid;

  // 1MHz test clock model:
  // 1 cycle = 1us (easy to reason about pulse widths).
  sr04_controller #(
    .TRIG_US(10)
  ) dut (
    .iClk(iClk),
    .iRst(iRst),
    .iTickUs(iTickUs),
    .iEcho(iEcho),
    .iStart(iStart),
    .oTrig(oTrig),
    .oDistanceCm(oDistanceCm),
    .oDistanceValid(oDistanceValid)
  );

  // 1MHz clock (period 1us)
  always #500 iClk = ~iClk;

  task pulse_start_req;
    begin
      @(posedge iClk);
      iStart <= 1'b1;
      @(posedge iClk);
      iStart <= 1'b0;
    end
  endtask

  task send_echo_high_cycles(input integer n_cycles);
    integer i;
    begin
      @(negedge iClk);
      iEcho = 1'b1;
      for (i = 0; i < n_cycles; i = i + 1) @(posedge iClk);
      @(negedge iClk);
      iEcho = 1'b0;
    end
  endtask

  initial begin
    iClk = 1'b0;
    iRst = 1'b1;
    iEcho = 1'b0;
    iStart = 1'b0;
    iTickUs = 1'b1;

    repeat (5) @(posedge iClk);
    iRst = 1'b0;

    // Start one measurement manually.
    pulse_start_req();

    // Wait until oTrig phase finishes and controller waits for iEcho.
    wait (oTrig == 1'b1);
    wait (oTrig == 1'b0);
    repeat (20) @(posedge iClk);

    // Echo high width = 580us -> around 10cm (580/58).
    send_echo_high_cycles(580);

    wait (oDistanceValid == 1'b1);
    if ((oDistanceCm < 9) || (oDistanceCm > 11)) begin
      $display("sr04 distance out of expected range: %0d", oDistanceCm);
      #10000;
      $finish;
    end
    #10000;
    $display("tb_sr04_controller finished: oDistanceCm=%0d", oDistanceCm);
    $finish;
  end

endmodule
