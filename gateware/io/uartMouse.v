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

  parameter BASE = 12'h3F8;

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

  wire rxReady;
  wire rxTaken;
  uart8250 #(.BASE(BASE)) uUart8250(
    .iClk    (iClk),
    .iAddr   (iAddr),
    .iWr     (iWr),
    .iWrData (iWrData),
    .iRd     (iRd),
    .oRdData (oRdData),
    .oSel    (oSel),
    .oIntr   (oIntr),
    .iRxData (mouseReset ? 8'h4D : uartRxData),
    .iRx     (mouseReset | uartRx),
    .oRxReady(),
    .oRxTaken(rxTaken),
    .iTxReady(1'b1),
    .oTxData (),
    .oTx     (),
    .oDTR    (),
    .oRTS    (rts)
  );

  wire rts;
  reg  dlyRts = 0;
  reg  mouseReset = 0;
  always @(posedge iClk) begin
    dlyRts <= rts;
    if ((!dlyRts) & rts) begin
      mouseReset <= 1;
      //state      <= 0;  // force PS/2 mouse to reset
    end
    if (rxTaken) begin
      mouseReset <= 0;
    end
  end

  localparam INTERVAL = `CLOCK_SPEED / 30;

  reg [19:0] period  = 0;
  reg [ 3:0] state   = 0;
  reg [23:0] ps2Recv = 0;

  reg [23:0] uartShift  = { 8'b01000000, 8'b00000000, 8'b00000000 };
  reg [ 7:0] uartRxData = 0;
  reg        uartRx     = 0;

  wire [8:0] mouseDxRaw =   {ps2Recv[20], ps2Recv[15:8] };
  wire [8:0] mouseDyRaw = (~{ps2Recv[21], ps2Recv[ 7:0] }) + 9'd1;

  wire [7:0] mouseDx  = mouseDxRaw[8:1];
  wire [7:0] mouseDy  = mouseDyRaw[8:1];
  wire       mouseLmb = ps2Recv[16];
  wire       mouseRmb = ps2Recv[17];

  wire [3:0] stateNext = state + 4'd1;

  always @(posedge iClk) begin
    period <= period - (|period);
    ps2Tx  <= 1'b0;
    uartRx <= 1'b0;

    case (state)

    //
    // reset
    //
    0: begin
      ps2TxData <= 8'hff;
      ps2Tx     <= ps2Idle;
      if (ps2TxOk) begin
        state <= stateNext;
      end
    end
    1: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? stateNext : 0;
      end
    end
    2: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'haa) ? stateNext : 0;
      end
    end
    3: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'h00) ? stateNext : 0;
      end
    end

    //
    // set defaults
    //
    4: begin
      ps2Tx     <= ps2Idle;
      ps2TxData <= 8'hf6;
      if (ps2TxOk) begin
        state <= stateNext;
      end
    end
    5: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? stateNext : 0;
      end
    end

    //
    // set scale 2:1
    //
    6: begin
      ps2Tx     <= ps2Idle;
      ps2TxData <= 8'he7;
      if (ps2TxOk) begin
        state <= stateNext;
      end
    end
    7: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? stateNext : 0;
      end
    end

    //
    // request sample
    //
    8: begin
      if (period == 0) begin
        // request single packet
        ps2Tx     <= ps2Idle;
        ps2TxData <= 8'heb;
        if (ps2TxOk) begin
          period <= INTERVAL;
          state  <= stateNext;
        end
      end
    end
    9: begin
      if (ps2Rx) begin
        // ACK bit
        state <= (ps2RxData == 8'hfa) ? stateNext : 8;
      end
    end
    10: begin
      if (ps2Rx) begin
        // byte1
        state   <= stateNext;
        ps2Recv <= { ps2Recv[15:0], ps2RxData };
        // forward to UART
        uartRx     <= 1'b1;
        uartRxData <= uartShift[23:16];
        uartShift  <= { uartShift[15:0], 8'd0 };
      end
    end
    11: begin
      if (ps2Rx) begin
        // byte2
        state   <= stateNext;
        ps2Recv <= { ps2Recv[15:0], ps2RxData };
        // forward to UART
        uartRx     <= 1'b1;
        uartRxData <= uartShift[23:16];
        uartShift  <= { uartShift[15:0], 8'd0 };
      end
    end
    12: begin
      if (ps2Rx) begin
        // byte3
        state   <= stateNext;
        ps2Recv <= { ps2Recv[15:0], ps2RxData };
        // forward to UART
        uartRx     <= 1'b1;
        uartRxData <= uartShift[23:16];
        uartShift  <= { uartShift[15:0], 8'd0 };
      end
    end

    //
    // convert
    //

    13: begin
      state <= 8;

      //              23            16   15            8    7             0
      //              7 6 5 4 3 2 1 0  | 7 6 5 4 3 2 1 0  | 7 6 5 4 3 2 1 0
      // PS/2 Format: YoXoYsXs1 BmBrBl | X7X6X5X4X3X2X1X0 | Y7Y6Y5Y4Y3Y2Y1Y0
      // M$ft Format: 0 1 BlBrY7Y6X7X6 | 0 0 X5X4X3X2X1X0 | 0 0 Y5Y4Y3Y2Y1Y0
      //

      uartShift <= {
//             Bl        Br        Y7,Y6         X7,X6
        2'b01, mouseLmb, mouseRmb, mouseDy[7:6], mouseDx[7:6],
        2'b00, mouseDx[5:0],
        2'b00, mouseDy[5:0]
      };
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
