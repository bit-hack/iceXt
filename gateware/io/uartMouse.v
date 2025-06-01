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
    .iRx     (mouseReset |         uartRx),
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
      //state <= STATE_RESET;  // TODO: force PS/2 mouse to reset
    end
    if (rxTaken) begin
      mouseReset <= 0;
    end
  end

  localparam INTERVAL = `CLOCK_SPEED / 30;

  reg [19:0] period  = 0;
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


  localparam STATE_RESET = 6;
  localparam STATE_POLL  = 0;

  reg [ 3:0] state     = STATE_RESET;
  wire [3:0] stateNext = state + 4'd1;


  always @(posedge iClk) begin
    period <= period - (|period);
    ps2Tx  <= 1'b0;
    uartRx <= 1'b0;

    case (state)

    //
    // request sample
    //
    STATE_POLL: begin
      if (period == 0) begin
        // request single packet
        ps2Tx     <= ps2Idle & !ps2TxOk;
        ps2TxData <= 8'heb;
        if (ps2TxOk) begin
          period <= INTERVAL;
          state  <= stateNext;
        end
      end
    end
    1: begin
      if (ps2Rx) begin
        // ACK bit
        state <= (ps2RxData == 8'hfa) ? stateNext : STATE_POLL;
      end
    end
    2: begin
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
    3: begin
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
    4: begin
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

    5: begin
      state <= STATE_POLL;
      uartShift <= {
        2'b01, mouseLmb, mouseRmb, mouseDy[7:6], mouseDx[7:6],
        2'b00, mouseDx[5:0],
        2'b00, mouseDy[5:0]
      };
    end

    //
    // reset
    //
    STATE_RESET: begin
      ps2TxData <= 8'hff;
      ps2Tx <= ps2Idle & !ps2TxOk;
      if (ps2TxOk) begin
        state <= stateNext;
      end
    end
    7: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? stateNext : STATE_RESET;
      end
    end
    8: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'haa) ? stateNext : STATE_RESET;
      end
    end
    9: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'h00) ? stateNext : STATE_RESET;
      end
    end

    //
    // set defaults
    //
    10: begin
      ps2Tx <= ps2Idle & !ps2TxOk;
      ps2TxData <= 8'hf6;
      if (ps2TxOk) begin
        state <= stateNext;
      end
    end
    11: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? stateNext : STATE_RESET;
      end
    end

    //
    // set scale 2:1
    //
    12: begin
      ps2Tx <= ps2Idle & !ps2TxOk;
      ps2TxData <= 8'he7;
      if (ps2TxOk) begin
        state <= stateNext;
      end
    end
    13: begin
      if (ps2Rx) begin
        state <= (ps2RxData == 8'hfa) ? STATE_POLL : STATE_RESET;
      end
    end

    //
    // unknown state
    //
    default: begin
      state <= STATE_RESET;
    end
    endcase

    // reset logic
    if (iRst) begin
      state <= STATE_RESET;
    end

  end

endmodule
