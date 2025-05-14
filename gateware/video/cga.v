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
    input       [ 2:0] iGlyphMaxY, // char height - 1
    output      [11:0] oAddr,      // character address [000.FFF] 8x8
    output      [ 2:0] oRA,        // row address [0..7]
    output      [ 3:0] oDA,        // dot address [0..15]
    output reg         oVgaVs,     // vertical sync
    output reg         oVgaHs,     // horizontal sync
    output             oVgaBlank   // vga blanking period
);

  // 640x400@70hz

  localparam xvis   = 639;          // visible area
  localparam xsyncs = 16 + xvis;    // front porch
  localparam xsynce = 96 + xsyncs;  // sync pulse
  localparam xmax   = 799;          // whole line

  localparam yvis   = 439;          // visible area
  localparam ysyncs = 12 + yvis;    // front porch
  localparam ysynce = 2  + ysyncs;  // sync pulse
  localparam ymax   = 448;          // whole line

  reg xblank = 0;
  reg yblank = 0;

  reg [ 9:0] xcounter = 0;
  reg [ 8:0] ycounter = 0;
  reg [11:0] yaddr    = 0;  // start of scanline memory address

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

  always @(posedge iClk25) begin
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
      ycounter <= ycounter + 9'd1;
      if (oRA == iGlyphMaxY) begin
        yaddr  <= yaddr + 12'd80;
      end
    end
    if (cmp_ymax) begin
      yblank   <= 0;
      ycounter <= 0;
      yaddr    <= 0;
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
    if (iWr & (iWrAddr[0] == 0) begin
      RAM[ iWrAddr[13:1] ][15:8] <= iWrData;
    end
    // low byte write
    if (iWr & (iWrAddr[0] == 1) begin
      RAM[ iWrAddr[13:1] ][ 7:8] <= iWrData;
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
    input        iClk,      // cpu domain clock
    input        iClk25,    // vga domain clock

    // cpu interface
    input [19:0] iAddr,     // read/write address
    input [ 7:0] iWrData,   // write io/mem data
    input        iWrMem,    // memory write
    input        iWrIo,     // io write
    input        iRdIo,     // io read
    output [7:0] oRdData,   // read io/mem data
    output       oSel       // read data valid

    // VGA interface
    output [3:0] oVgaR,
    output [3:0] oVgaG,
    output [3:0] oVgaB,
    output       oVgaHs,
    output       oVgaVs
);

  //
  // CGA font ROM
  //
  reg [7:0] font[2048];
  initial $readmemb("roms/font8x8.hex", font);

  //
  // mode control register
  //
  reg  [7:0] reg3D8        = 8'b00001000;
  wire       regBlink      = reg3D8[5];
  wire       regHiResGfx   = reg3D8[4];
  wire       regVideoOutEn = reg3D8[3];
  wire       regBnW        = reg3D8[2];
  wire       regGfxMode    = reg3D8[1];
  wire       regHiResTxt   = reg3D8[0];

  //
  // color control register
  //
  reg  [7:0] reg3D9        = 8'b00010000;
  wire       regPalette    = reg3D9[5];
  wire       regBrightFg   = reg3D9[4];
  wire [3:0] regColor      = reg3D9[3:0];

  //
  // status register
  //
  wire [7:0] reg3DA        = 8'b1111_1_0_0_1;

  //
  // port read/write logic
  //
  always (posedge iClk) begin
    iRdData <= 12'h0;
    case (iAddr[11:0])
    12'h3D8: begin
      if (iWrIo) reg3D8  <= iWrData;
      if (iRdIo) iRdData <= reg3D8;
    end
    12'h3D9: begin
      if (iWrIo) reg3D9  <= iWrData;
      if (iRdIo) iRdData <= reg3D9;
    end
    12'h3DA: begin
      if (iRdIo) iRdData <= reg3DA;
    end
    endcase
  end

  //
  // CRTC
  //
  wire [11:0] crtcAddr;
  wire [ 2:0] crtcRA;
  wire [ 3:0] crtcDA;
  wire        crtcVS;
  wire        crtcHS;
  wire        crtcBlank;
  video_crtc u_video_crtc(
    .iClk25    (iClk25),
    .iGlyphMaxY(3'd7),  // 1 for graphics mode?
    .oAddr     (crtcAddr),
    .oRA       (crtcRA),
    .oDA       (crtcDA),
    .oVgaVS    (crtcVS),
    .oVgaHS    (crtcHS),
    .oVgaBlank (crtcBlank)
  );

  //
  // delays
  //
  reg [ 3:0] dlyCrtcVS;
  reg [ 3:0] dlyCrtcHS;
  reg [ 3:0] dlyCrtcBlank;
  reg [ 3:0] dlyCrtcDA1;
  always @(posedge iClk25) begin
    dlyCrtcVS    <= { dlyCrtcVS   [2:0], crtcVS };
    dlyCrtcHS    <= { dlyCrtcHS   [2:0], crtcHS };
    dlyCrtcBlank <= { dlyCrtcBlank[2:0], crtcBlank };
    dlyCrtcDa1   <= crtcDA;
  end

  //
  // address generators
  //
  wire [13:0] ramAddrTxt = { crtcAddr, 1'b0 };
  wire [13:0] ramAddrGfx = 14'd0;

  //
  // video ram
  //
  wire        ramSel = iAddr[19:15] == 5'b10111;  // [B8000..Bffff]
  wire [13:0] ramRdAddr = ramAddrTxt;
  wire [15:0] ramRdData;
  video_ram u_video_ram(
    .iClk   (iClk),     // WR clock
    .iClk25 (iClk25),   // RD clock
    .iWrAddr(iAddr),
    .iWr    (iWrMem & ramSel),
    .iWrData(iData),
    .iRdAddr(ramRdAddr),
    .oRdData(ramRdData)
  );

  wire [7:0] txtChar = ramRdData[15:8];  // ramRdAddr[0]==0
  wire [7:0] txtAttr = ramRdData[ 7:0];  // ramRdAddr[0]==1

  //
  // font lookup
  //
  wire [10:0] glyphAddr = { txtChar, crtcRA[2:0] };
  reg  [ 7:0] glyphRow;
  reg         glyphBit;
  wire [ 3:0] glyphVal = glyphBit ? 4'hf : 4'h0;

  always @(posedge iClk) begin
    glyphRow <= font[glyphAddr];
    glyphBit <= glyphRow[dlyCrtcDa1[3:1]];
  end

  //
  // vga output
  //
  assign oVgaR  = dlyCrtcBlank[1] ? 4'd0 : glyphVal;
  assign oVgaG  = dlyCrtcBlank[1] ? 4'd0 : glyphVal;
  assign oVgaB  = dlyCrtcBlank[1] ? 4'd0 : glyphVal;
  assign oVgaHs = dlyCrtcHS[1];
  assign oVgaVs = dlyCrtcVS[1];

endmodule
