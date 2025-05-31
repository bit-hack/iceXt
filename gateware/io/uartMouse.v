/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "../config.vh"


module uartMouse(

  // cpu interface
  input  wire        iClk,
  input  wire        iRst,
  input  wire [19:0] iAddr,
  input  wire        iWr,
  input  wire  [7:0] iWrData,
  input  wire        iRd,
  output wire  [7:0] oRdData,
  output wire        oSel,
  output wire        oIntr,

  // PS/2 interface
  input  wire        iPs2Clk,
  input  wire        iPs2Data,
  output wire        oPs2Clk,
  output wire        oPs2Data
);

  reg        ps2Tx     = 0;
  reg  [7:0] ps2TxData = 0;
  wire       ps2TxOk;
  wire       ps2TxFail;
  wire       ps2Rx;
  wire [7:0] ps2RxData;
  wire       ps2Idle;
  ps2_device uPs2Device(
    .iClk    (iClk),
    .iTx     (ps2Tx),
    .iTxData (ps2TxData),
    .oTxOk   (ps2TxOk),
    .oTxFail (ps2TxFail),
    .iInhibit(1'b0),
    .oIdle   (ps2Idle),
    .oRx     (ps2Rx),
    .oRxData (ps2RxData),
    .iPs2Clk (iPs2Clk),
    .iPs2Dat (iPs2Data),
    .oPs2Clk (oPs2Clk),
    .oPs2Dat (oPs2Data)
  );

  localparam INTERVAL = `CLOCK_SPEED / 30;

  reg [19:0] period  = 0;
  reg [ 3:0] state   = 0;
  reg [23:0] ps2Recv = 0;

  always @(posedge iClk) begin
    period <= period - (|period);
    ps2Tx  <= 1'b0;

    case (state)

    //
    // reset
    //
    0: begin
      ps2TxData <= 8'hff;
      ps2Tx     <= ps2Idle;
      if (ps2TxOk) begin
        state <= 1;
      end
    end
    1: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? 2 : 0;
      end
    end
    2: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'haa) ? 3 : 0;
      end
    end
    3: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'h00) ? 4 : 0;
      end
    end

    //
    // set defaults
    //
    4: begin
      ps2Tx     <= ps2Idle;
      ps2TxData <= 8'hf6;
      if (ps2TxOk) begin
        state <= 5;
      end
    end
    5: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? 6 : 0;
      end
    end

    //
    // request sample
    //
    6: begin
      if (period == 0) begin
        ps2Tx     <= ps2Idle;
        ps2TxData <= 8'heb;
        if (ps2TxOk) begin
          period <= INTERVAL;
          state  <= 7;
        end
      end
    end
    7: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? 8 : 6;
      end
    end
    8: begin
      if (ps2Rx) begin
        state   <= 9;
        ps2Recv <= { ps2Recv[15:0], ps2RxData };
      end
    end
    9: begin
      if (ps2Rx) begin
        state   <= 10;
        ps2Recv <= { ps2Recv[15:0], ps2RxData };
      end
    end
    10: begin
      if (ps2Rx) begin
        state   <= 6;
        ps2Recv <= { ps2Recv[15:0], ps2RxData };
      end
    end

    //
    // unknown state
    //
    default: begin
      state <= 0;
    end
    endcase

    // reset logic
    if (iRst) begin
      state <= 0;
    end

  end

endmodule
