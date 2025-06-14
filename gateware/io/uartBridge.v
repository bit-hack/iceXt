/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "../config.vh"


module uartBridge(

  // cpu interface
  input  wire        iClk,
  input  wire [19:0] iAddr,
  input  wire        iWr,
  input  wire  [7:0] iWrData,
  input  wire        iRd,
  output wire  [7:0] oRdData,
  output wire        oSel,
  output wire        oIntr,

  // FPGA uart
  input  wire        iRx,
  output wire        oTx
);

  parameter BASE = 12'h3F8;

  wire [7:0] rxData;
  wire       rxValid;
  uartRx #(.CLK_FREQ(`CLOCK_SPEED)) uUartRx(
    .iClk  (iClk),
    .iRx   (iRx),
    .oData (rxData),
    .oValid(rxValid),
    .oBusy ()
  );

  wire       rxTaken;
  uart8250 #(.BASE(BASE)) uUart8250(
    .iClk    (iClk),
    .iAddr   (iAddr),
    .iWr     (iWr),
    .iWrData (iWrData),
    .iRd     (iRd),
    .oRdData (oRdData),
    .oSel    (oSel),
    .oIntr   (oIntr),
    .iRxData (rxData),
    .iRx     (rxValid),
    .oRxReady(),
    .oRxTaken(rxTaken),
    .iTxReady(txReady),
    .oTxData (txData),
    .oTx     (txValid),
    .oDTR    (),
    .oRTS    ()
  );

  wire       txReady;
  wire       txValid;
  wire [7:0] txData;
  uartTx #(.CLK_FREQ(`CLOCK_SPEED)) uUartTx(
    .iClk  (iClk),
    .iRst  (1'b0),
    .iData (txData),
    .iStart(txValid),
    .oTx   (oTx),
    .oBusy (),
    .oReady(txReady),
    .oTaken()
  );

endmodule
