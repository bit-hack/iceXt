/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module adlib(
    input        iClk,
    input        iRst,

    // CPU interface
    input        iWr,
    input [ 7:0] iWrData,
    input [19:0] iAddr,

    // ym3014 DAC
    output       oYmSd,
    output       oYmLoad,
    output       oYmClk,
);

  wire adlibClkEn;
  clkEnGen #(.CLK_IN(10000000)) uClkEnGen (
    .iClk  (iClk),
    .oClkEn(adlibClkEn)
  );

  wire signed [15:0] adlibSnd;

  wire selected = { iAddr[11:1], 1'b0 } == 12'h388;

  jtopl2 uJtopl2 (
    .rst   (iRst),  // active high
    .clk   (iClk),
    .cen   (adlibClkEn),
    .din   (iWrData),
    .addr  (iAddr[0]),  // 0=addr, 1=data
    .cs_n  (~(selected & iWr)),
    .wr_n  (~(selected & iWr)),
    .dout  (),
    .irq_n (),
    .snd   (adlibSnd),
    .sample()
  );

  ym3014 ymDac (
    .iClk    (iClk),
    .iClkEn  (adlibClkEn),
    .iSample (adlibSnd),
    .oDacClk (oYmClk),
    .oDacLoad(oYmLoad),
    .oDacSd  (oYmSd)
  );

endmodule
