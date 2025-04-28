`default_nettype none

`include "config.vh"


module top(
    input        clk25,
    input        serial_rx,
    input        sw_rst,
    output [7:0] pmod,
    output       ym_sd,
    output       ym_load,
    output       ym_clk,
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output       vga_vs,
    output       vga_hs
    );

  wire rst;
  reset uReset (
    .iClk  (clk25),
    .iReset(~sw_rst),
    .oReset(rst)
  );

  wire       rxBusy;
  wire       rxValid;
  wire [7:0] rxData;
  uartRx uUartRx(
    .iClk  (clk25),
    .iRx   (serial_rx),
    .oData (rxData),
    .oValid(rxValid),
    .oBusy (rxBusy)
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

`ifdef CFG_ADLIB_ENABLE
  reg        write;
  reg [23:0] sreg;
  always @(posedge clk25) begin
    write <= 0;
    if (rxValid) begin
      sreg <= { sreg[ 16:0 ], rxData[6:0] };
      write <= rxData[7];
    end
  end
`endif  // CFG_ADLIB_ENABLE

  wire adlibClkEn;
  clkEnGen uClkEnGen (
    .iClk  (clk25),
    .oClkEn(adlibClkEn)
  );

  wire signed [15:0] adlibSnd = 16'd0;
`ifdef CFG_ADLIB_ENABLE
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
`endif  // CFG_ADLIB_ENABLE

  ym3014 ymDac (
    .iClk    (clk25),
    .iClkEn  (adlibClkEn),
    .iSample (adlibSnd),
    .oDacClk (ym_clk),
    .oDacLoad(ym_load),
    .oDacSd  (ym_sd)
  );

  video_mda u_video_mda(
    /*input        */.iClk  (clk25),
    /*input        */.iClk25(clk25),
    /*input [19:0] */.iAddr (wr_addr),
    /*input [ 7:0] */.iData (rxData),
    /*input        */.iWr   (rxValid),
    /*output [3:0] */.oVgaR (vga_r),
    /*output [3:0] */.oVgaG (vga_g),
    /*output [3:0] */.oVgaB (vga_b),
    /*output       */.oVgaHs(vga_hs),
    /*output       */.oVgaVs(vga_vs)
  );

  reg [19:0] wr_addr;
  initial begin
    wr_addr = 20'hb0000;
  end
  always @(posedge clk25) begin
    if (rxValid) begin
      wr_addr <= wr_addr + 1;
    end
  end

endmodule
