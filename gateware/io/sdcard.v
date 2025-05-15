/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module sdCard(
    input        iClk,
    input [19:0] iAddr,
    input        iWr,
    input        iRd,
    input  [7:0] iData,
    output [7:0] oData,
    output       oSel,
    input        iSdMiso,
    output       oSdMosi,
    output       oSdSck,
    output       oSdCs,
    output       oBusy,
    output       oClick
);

  assign oBusy  = ~sd_busy;
  assign oSdCs  = spi_cs;
  assign oData  = sd_latch_rx;
  assign oClick = click;

  wire [7:0] sd_rx;
  wire       sd_valid;
  wire       sd_busy;
  reg        sd_send = 0;
  reg        oSel    = 0;
  reg        spi_cs  = 1;
  reg        click   = 0;

  reg [7:0] sd_latch_rx = 0;
  reg [7:0] sd_latch_tx = 0;

  spiMaster uSpiMaster(
    /*input        */.iClk   (iClk),
    /*input  [3:0] */.iClkDiv(4'd15),
    /*input        */.iSend  (sd_send),
    /*input  [7:0] */.iData  (sd_latch_tx),
    /*output [7:0] */.oData  (sd_rx),
    /*output reg   */.oAvail (sd_valid),
    /*output reg   */.oTaken (),
    /*output       */.oBusy  (sd_busy),
    /*output       */.oMosi  (oSdMosi),
    /*input        */.iMiso  (iSdMiso),
    /*output reg   */.oSck   (oSdSck)
  );

  always @(posedge iClk) begin
    sd_send <= 0;
    oSel    <= 0;
    if (sd_valid) begin
      sd_latch_rx <= sd_rx;
    end
    if (iWr) begin
      if (iAddr[11:0] == 12'h0b9) begin
        spi_cs <= iData[0];
      end
      if (iAddr[11:0] == 12'h0b8) begin
        sd_send     <= 1;
        sd_latch_tx <= iData;
      end
      if (iAddr[11:0] == 12'h0ba) begin
        click <= !click;
      end
    end
    if (iRd) begin
      if (iAddr[11:0] == 12'h0b8) begin
        oSel <= 1;
      end
    end
  end

endmodule
