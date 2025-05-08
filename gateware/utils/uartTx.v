`default_nettype none

// Uart waveform:
//
//       lsb ------- msb
//     S 0 1 2 3 4 5 6 7 S
//     | | | | | | | | | |
//  --. .-.   .-. .-.   .---
//    |_| |___| |_| |___|
//

module uartTx (
    input            iClk,    // clock
    input            iRst,    // reset
    input      [7:0] iData,   // data to send
    input            iStart,  // send iData
    output reg       oTx,     // output tx line
    output           oBusy,   // tx is active
    output           oReady,  // waiting for start
    output reg       oTaken   // input data taken
);

  parameter CLK_FREQ = 10000000;
  parameter BAUD = 115200;
  integer delta = 32'h8000 / (CLK_FREQ / BAUD);

  // start conditions
  wire start = oReady && iStart;

  // sample counter handling
  reg [15:0] counter = 0;
  wire step = counter[15];
  always @(posedge iClk) begin
    if (iRst || start) begin
      counter <= 16'd0;
    end else begin
      counter <= {1'b0, counter[14:0]} + delta;
    end
  end

  assign oReady = (data == 0);
  assign oBusy  = |data;

  always @(posedge iClk) begin
    oTaken <= 0;
    if (start) begin
      oTaken <= 1'b1;
    end
  end

  // data shifter
  reg [9:0] data = 0;
  always @(posedge iClk) begin
    data <= iRst ? 10'd0 : start ? {1'b1, iData, 1'b0} : step ? {1'b0, data[9:1]} : data;
  end

  // output register
  always @(posedge iClk) begin
    oTx <= (|data) ? data[0] : 1'b1;
  end

endmodule
