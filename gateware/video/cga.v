/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module video_crtc(
    input              iClk25,
    input       [ 2:0] iGlyphMaxY,  // char height - 1
    output      [12:0] oAddr,       // character address [000.1FFF] 8x8
    output      [ 2:0] oRA,         // row address [0..7]
    output      [ 3:0] oDA,         // dot address [0..15]
    output reg         oVgaHs,      // horizontal sync
    output reg         oVgaVs,      // vertical sync
    output             oVgaBlank,   // vga blanking period
    output reg         oVgaRetrace  // vertical retrace strobe
);

  // 640x400@70hz

  localparam xvis   = 639;          // visible area
  localparam xsyncs = 16 + xvis;    // front porch
  localparam xsynce = 96 + xsyncs;  // sync pulse
  localparam xmax   = 799;          // whole line

  localparam yvis   = 399;          // visible area
  localparam ysyncs = 12 + yvis;    // front porch
  localparam ysynce = 2  + ysyncs;  // sync pulse
  localparam ymax   = 448;          // whole line

  reg xblank = 0;
  reg yblank = 0;

  reg [ 9:0] xcounter = 0;
  reg [ 9:0] ycounter = 0;
  reg [12:0] yaddr    = 0;  // start of scanline memory address

  wire cmp_xvis    = (xcounter == xvis);     // front porch start
  wire cmp_xsyncs  = (xcounter == xsyncs);   // sync start
  wire cmp_xsynce  = (xcounter == xsynce);   // sync end
  wire cmp_xmax    = (xcounter == xmax);     // retrace

  wire cmp_yvis    = (ycounter == yvis);
  wire cmp_ysyncs  = (ycounter == ysyncs);
  wire cmp_ysynce  = (ycounter == ysynce);
  wire cmp_ymax    = (ycounter == ymax);

  assign oVgaBlank = xblank | yblank;
  assign oDA       = xcounter[3:0];         // 640 resolution
  assign oRA       = ycounter[3:1];         // 200 resolution
  assign oAddr     = yaddr + xcounter[9:3]; // 8x8 pixels granularity

  wire [3:0] glyphMaxY = { iGlyphMaxY, 1'b1 };

  always @(posedge iClk25) begin
    if (cmp_xmax) begin
      if ((ycounter[3:0] & glyphMaxY) == glyphMaxY) begin
        yaddr <= yaddr + 13'd80;
      end
      if (cmp_ymax) begin
        yaddr <= 0;
      end
    end
  end

  always @(posedge iClk25) begin
    oVgaRetrace <= 0;
    xcounter <= xcounter + 10'd1;
    oVgaHs <= cmp_xsyncs ? 0 :  // negative pulse
              cmp_xsynce ? 1 :
              oVgaHs;
    oVgaVs <= cmp_ysyncs ? 1 :  // positive pulse
              cmp_ysynce ? 0 :
              oVgaVs;
    if (cmp_xvis) begin
      xblank <= 1;
    end
    if (cmp_yvis) begin
      yblank <= 1;
    end
    if (cmp_xmax) begin
      xblank   <= 0;
      xcounter <= 0;
      ycounter <= ycounter + 10'd1;
      if (cmp_ymax) begin
        yblank      <= 0;
        ycounter    <= 0;
        oVgaRetrace <= 1;
      end
    end
  end

endmodule


module video_ram(
    input             iClk,       // write port clock
    input             iClk25,     // read port clock

    // write port
    input      [13:0] iWrAddr,    // 0..16k
    input             iWr,
    input      [ 7:0] iWrData,

    // read port
    input      [13:0] iRdAddr,    // 0..16k
    output reg [15:0] oRdData
);

  // 0    1    2    3    ...
  // <chr><atr><chr><atr>...

  // note: arrange so gfx mode pixels are linear
  //  7:0 - attribute
  // 15:8 - character
  reg [15:0] RAM[8192];  // 16KB
  initial $readmemh("roms/test_vram_txt.hex", RAM);

  //
  // cpu write port
  //
  always @(posedge iClk) begin
    // high byte write
    if (iWr & (iWrAddr[0] == 0)) begin
      RAM[ iWrAddr[13:1] ][15:8] <= iWrData;
    end
    // low byte write
    if (iWr & (iWrAddr[0] == 1)) begin
      RAM[ iWrAddr[13:1] ][ 7:0] <= iWrData;
    end
  end

  //
  // vga read port
  //
  always @(posedge iClk25) begin
    oRdData <= RAM[ iRdAddr[ 13:1 ] ];
  end

endmodule


module video_cga(
    input            iClk,      // cpu domain clock
    input            iClk25,    // vga domain clock

    // cpu interface
    input [19:0]     iAddr,     // read/write address
    input [ 7:0]     iWrData,   // write io/mem data
    input            iWrMem,    // memory write
    input            iWrIo,     // io write
    input            iRdIo,     // io read
    output reg [7:0] oRdData,   // read io/mem data
    output           oSel,      // read data valid

    // VGA interface
    output [3:0]     oVgaR,
    output [3:0]     oVgaG,
    output [3:0]     oVgaB,
    output           oVgaHs,
    output           oVgaVs
);

  // todo:
  //  hi-res modes
  //  cursor
  //  regColor handling

  //
  // CGA font ROM
  //
  reg [7:0] font[2048];
  initial $readmemb("roms/font8x8.hex", font);

  //
  // mode control register
  //
  reg  [7:0] reg3D8        = 8'b00_0_0_1_0_0_0;
  wire       regBlink      = reg3D8[5];
  wire       regHiResGfx   = reg3D8[4];
  wire       regVideoOutEn = reg3D8[3];
  wire       regBnW        = reg3D8[2];
  wire       regGfxMode    = reg3D8[1];
  wire       regHiResTxt   = reg3D8[0];

  //
  // color control register
  //
  reg  [7:0] reg3D9      = 8'b00_1_0_0000;
  wire       regPalette  = reg3D9[5];
  wire       regBrightFg = reg3D9[4];
  wire [3:0] regColor    = reg3D9[3:0];

  //
  // CRTC 6845 registers
  //
  reg  [ 4:0] regCRTCIndex = 5'd0;
  reg  [ 7:0] regCRTCValue[18];
  wire [ 4:0] cursorStart =   regCRTCValue[10][4:0];
  wire [ 4:0] cursorEnd   =   regCRTCValue[11][4:0];
  wire [13:0] cursorAddr  = { regCRTCValue[14][5:0], regCRTCValue[15] };
  wire [ 1:0] cursorMode  =   2'b11;  // regCRTCValue[10][6:5];

  initial begin
    regCRTCValue[10] = 8'hf0;  // blink
  end

  wire cursor = ({ 1'b0, crtcAddr } == cursorAddr ) &&
                ({ 2'd0, crtcRA   } >= cursorStart) &&
                ({ 2'd0, crtcRA   } <= cursorEnd  ) &&
                (cursorMode != 2'b01) &&
                (cursorMode == 2'b10 ? blink[3] : 1'b1) &&
                (cursorMode == 2'b11 ? blink[4] : 1'b1);

  //
  // status register
  //
  wire [7:0] reg3DA = {
    4'hf,       // unused
    oVgaVs,     // vertical retrace
    1'b0,       // light pen switch
    1'b0,       // light pen trigger
    !active     // display enable
  };

  //
  // port read/write logic
  //
  always @(posedge iClk) begin
    oRdData <= 12'h0;
    oSel    <= 1'b0;
    case (iAddr[11:0])
    12'h3B0, 12'h3B2, 12'h3B4, 12'h3B6, 12'h3D0, 12'h3D2, 12'h3D4, 12'h3D6: begin
      if (iWrIo) begin
        regCRTCIndex <= iWrData[4:0];
      end
      if (iRdIo) begin
        oRdData <= regCRTCIndex;
        oSel    <= 1'b1;
      end
    end
    12'h3B1, 12'h3B3, 12'h3B5, 12'h3B7, 12'h3D1, 12'h3D3, 12'h3D5, 12'h3D7: begin
      if (regCRTCIndex < 5'd18) begin
        if (iWrIo) begin
          regCRTCValue[regCRTCIndex] <= iWrData;
        end
        if (iRdIo) begin
          oRdData <= regCRTCValue[regCRTCIndex];
          oSel    <= 1'b1;
        end
      end
    end
    12'h3D8: begin
      if (iWrIo) reg3D8  <= iWrData;
      if (iRdIo) { oRdData, oSel } <= { reg3D8, 1'b1 };
    end
    12'h3D9: begin
      if (iWrIo) reg3D9  <= iWrData;
      if (iRdIo) { oRdData, oSel } <= { reg3D9, 1'b1 };
    end
    12'h3DA: begin
      if (iRdIo) { oRdData, oSel } <= { reg3DA, 1'b1 };
    end
    endcase
  end

  //
  // CRTC
  //
  wire [ 2:0] glyphMaxY = regGfxMode ? 3'd1 : 3'd7;
  wire [12:0] crtcAddr;
  wire [ 2:0] crtcRA;
  wire [ 3:0] crtcDA;
  wire        crtcVS;
  wire        crtcHS;
  wire        crtcBlank;
  wire        crtcRetrace;
  video_crtc u_video_crtc(
    .iClk25     (iClk25),
    .iGlyphMaxY (glyphMaxY),
    .oAddr      (crtcAddr),
    .oRA        (crtcRA),
    .oDA        (crtcDA),
    .oVgaVs     (crtcVS),
    .oVgaHs     (crtcHS),
    .oVgaBlank  (crtcBlank),
    .oVgaRetrace(crtcRetrace)
  );

  //
  // blink
  //

  reg [4:0] blink = 0;
  always @(posedge iClk25) begin
    if (crtcRetrace) begin
      blink <= blink + 5'd1;
    end
  end

  //
  // delays
  //
  reg [ 2:0] dlyCrtcVS;
  reg [ 2:0] dlyCrtcHS;
  reg [ 2:0] dlyCrtcBlank;
  reg [ 3:0] dlyCrtcDA1, dlyCrtcDA2;
  reg [ 2:0] dlyCrtcRA1;
  reg [ 7:0] dlyTxtAttr1, dlyTxtAttr2;
  reg        dlyCursor1, dlyCursor2;

  always @(posedge iClk25) begin
    dlyCrtcVS    <= { dlyCrtcVS   [1:0], crtcVS };
    dlyCrtcHS    <= { dlyCrtcHS   [1:0], crtcHS };
    dlyCrtcBlank <= { dlyCrtcBlank[1:0], crtcBlank };
    dlyCrtcRA1   <= crtcRA;
    { dlyCrtcDA2,  dlyCrtcDA1  } <= { dlyCrtcDA1,  crtcDA  };
    { dlyTxtAttr2, dlyTxtAttr1 } <= { dlyTxtAttr1, txtAttr };
    { dlyCursor2,  dlyCursor1  } <= { dlyCursor1,  cursor  };
  end

  //
  // address generators
  //
  wire [13:0] ramAddrTxt = { crtcAddr[12:0], 1'b0 };
  wire [13:0] ramAddrGfx = { crtcRA[0], crtcAddr[12:0] };

  //
  // video RAM
  //
  wire        ramSel = iAddr[19:15] == 5'b10111;  // [B8000..Bffff]
  wire [13:0] ramRdAddr = regGfxMode ? ramAddrGfx : ramAddrTxt;
  wire [15:0] ramRdData;
  video_ram u_video_ram(
    .iClk   (iClk),     // WR clock
    .iClk25 (iClk25),   // RD clock
    .iWrAddr(iAddr),
    .iWr    (iWrMem & ramSel),
    .iWrData(iWrData),
    .iRdAddr(ramRdAddr),
    .oRdData(ramRdData)
  );

  wire [7:0] txtChar = ramRdData[15:8];  // ramRdAddr[0]==0
  wire [7:0] txtAttr = dlyCursor1 ? { ramRdData[3:0], ramRdData[3:0] } :
                                      ramRdData[7:0];  // ramRdAddr[0]==1

  //
  // font ROM lookup
  //
  wire [10:0] glyphAddr = { txtChar, dlyCrtcRA1 };
  reg  [ 7:0] glyphRow;
  reg         glyphBit;

  always @(posedge iClk25) begin
    glyphRow <= font[glyphAddr];
    glyphBit <= glyphRow[ dlyCrtcDA2[2:0] ];
  end

  //
  // glyph color lookup
  //
  reg [11:0] palCga[16];
  initial begin
    palCga[ 0] = 12'h000;
    palCga[ 1] = 12'h00a;
    palCga[ 2] = 12'h0a0;
    palCga[ 3] = 12'h0aa;
    palCga[ 4] = 12'ha00;
    palCga[ 5] = 12'ha0a;
    palCga[ 6] = 12'ha50;
    palCga[ 7] = 12'haaa;
    palCga[ 8] = 12'h555;
    palCga[ 9] = 12'h55f;
    palCga[10] = 12'h5f5;
    palCga[11] = 12'h5ff;
    palCga[12] = 12'hf55;
    palCga[13] = 12'hf5f;
    palCga[14] = 12'hff5;
    palCga[15] = 12'hfff;
  end

  // note: we could register these if needed
  wire [11:0] colorFg = palCga[ dlyTxtAttr2[3:0] ];
  wire [11:0] colorBg = palCga[ dlyTxtAttr2[7:4] ];
  
  wire [3:0] glyphR = glyphBit ? colorFg[11:8] : colorBg[11:8];
  wire [3:0] glyphG = glyphBit ? colorFg[ 7:4] : colorBg[ 7:4];
  wire [3:0] glyphB = glyphBit ? colorFg[ 3:0] : colorBg[ 3:0];

  //
  // graphics mode pixel lookup
  //
  reg [1:0] pixel;
  always @(posedge iClk25) begin
    case (dlyCrtcDA1[3:1])
    0: pixel <= ramRdData[15:14];
    1: pixel <= ramRdData[13:12];
    2: pixel <= ramRdData[11:10];
    3: pixel <= ramRdData[ 9: 8];
    4: pixel <= ramRdData[ 7: 6];
    5: pixel <= ramRdData[ 5: 4];
    6: pixel <= ramRdData[ 3: 2];
    7: pixel <= ramRdData[ 1: 0];
    endcase
  end

  //
  // graphics mode palette lookup
  //
  reg [11:0] palGfx[16];
  initial begin
    palGfx[ 0] = 12'h000;  // 0   .. pal=0, intensity=0
    palGfx[ 1] = 12'h0a0;  // 2
    palGfx[ 2] = 12'ha00;  // 4
    palGfx[ 3] = 12'ha50;  // 6
    palGfx[ 4] = 12'h000;  // 0   .. pal=0, intensity=1
    palGfx[ 5] = 12'h5f5;  // 10
    palGfx[ 6] = 12'hf55;  // 12
    palGfx[ 7] = 12'hff5;  // 14
    palGfx[ 8] = 12'h000;  // 0   .. pal=1, intensity=0
    palGfx[ 9] = 12'h0aa;  // 3
    palGfx[10] = 12'ha0a;  // 5
    palGfx[11] = 12'haaa;  // 7
    palGfx[12] = 12'h000;  // 0   .. pal=1, intensity=1
    palGfx[13] = 12'h5ff;  // 11
    palGfx[14] = 12'hf5f;  // 13
    palGfx[15] = 12'hfff;  // 15
  end

  reg  [3:0] pixR;
  reg  [3:0] pixG;
  reg  [3:0] pixB;
  wire [3:0] palIndex = { regPalette, regBrightFg, pixel };

  always @(posedge iClk25) begin
    { pixR, pixG, pixB } <= palGfx[ palIndex ];
  end

  //
  // GFX/TXT MUX
  //
  wire [3:0] outR = regGfxMode ? pixR : glyphR;
  wire [3:0] outG = regGfxMode ? pixG : glyphG;
  wire [3:0] outB = regGfxMode ? pixB : glyphB;

  //
  // vga output
  //
  wire active = regVideoOutEn & !dlyCrtcBlank[2];
  assign oVgaR  = active ? outR : 4'h0;
  assign oVgaG  = active ? outG : 4'h0;
  assign oVgaB  = active ? outB : 4'h0;
  assign oVgaHs = dlyCrtcHS[2];
  assign oVgaVs = dlyCrtcVS[2];

endmodule
