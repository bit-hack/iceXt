`default_nettype none


module top(
    input        clk25,
    input        serial_rx,
    input        sw_rst,
    output [7:0] pmod,
    output       ym_sd,
    output       ym_load,
    output       ym_clk
    );

  wire rst;
  reset uReset (
      .iClk  (clk25),
      .iReset(0),
      .oReset(rst)
  );

  wire       rxBusy;
  wire       rxValid;
  wire [7:0] rxData;
  uartRx uUartRx(
    /*input        */.iClk   (clk25),
    /*input        */.iRx    (serial_rx),
    /*output [7:0] */.oData  (rxData),
    /*output reg   */.oValid (rxValid),
    /*output       */.oBusy  (rxBusy)
  );

  reg [7:0] value;
  always @(posedge clk25) begin
    if (rxValid) begin
      value <= rxData;
    end
  end

  wire [ 6:0] segs;
  wire        sel;

  sevenSeg seg(.clk(clk25), .value(value), .led(segs), .sel(sel));

  //                 J14, H14,     G14,     F14,     K13,     J13,     H13,     G13
  //                 sel, A,       D,       G,       C,       B,       E,       F  
  wire [7:0] leds = {sel, segs[0], segs[3], segs[6], segs[2], segs[1], segs[4], segs[5] };

  assign pmod = leds;

  reg        write;
  reg [23:0] sreg;
  always @(posedge clk25) begin
    write <= 0;
    if (rxValid) begin
      sreg <= { sreg[ 16:0 ], rxData[6:0] };
      write <= rxData[7];
    end
  end

  wire adlibClkEn;
  clkEnGen uClkEnGen (
      .iClk  (clk25),
      .oClkEn(adlibClkEn)
  );

  wire signed [15:0] adlibSnd;
  wire               adlibSample;
  jtopl2 uJtopl2 (
      .rst   (rst),  // active high
      .clk   (clk25),
      .cen   (adlibClkEn),
      .din   (sreg[7:0]),
      .addr  (sreg[8]),  // 0=addr, 1=data
      .cs_n  (~write),
      .wr_n  (~write),
      .dout  (),
      .irq_n (),
      .snd   (adlibSnd),
      .sample(adlibSample)
  );

  ym3014 ymDac (
    .iClk    (clk25),
    .iClkEn  (adlibClkEn),
    .iSample (adlibSnd),
    .oDacClk (ym_clk),
    .oDacLoad(ym_load),
    .oDacSd  (ym_sd)
  );

endmodule
