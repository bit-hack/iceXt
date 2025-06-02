/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module video_crtc_ega(
    input              iClk25,
    input       [ 2:0] iGlyphMaxY, // char height - 1
    output      [13:0] oAddr,      // character address [000.1FFF] 8x8
    output      [ 2:0] oRA,        // row address [0..7]
    output      [ 2:0] oDA,        // dot address [0..7]
    output reg         oVgaHs,     // horizontal sync
    output reg         oVgaVs,     // vertical sync
    output             oVgaBlank   // vga blanking period
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
  reg [13:0] yaddr    = 0;  // start of scanline memory address

  wire cmp_xvis    = (xcounter == xvis);     // front porch start
  wire cmp_xsyncs  = (xcounter == xsyncs);   // sync start
  wire cmp_xsynce  = (xcounter == xsynce);   // sync end
  wire cmp_xmax    = (xcounter == xmax);     // retrace

  wire cmp_yvis    = (ycounter == yvis);
  wire cmp_ysyncs  = (ycounter == ysyncs);
  wire cmp_ysynce  = (ycounter == ysynce);
  wire cmp_ymax    = (ycounter == ymax);

  assign oVgaBlank = xblank | yblank;
  assign oDA       = xcounter[3:1];          // 320 resolution
  assign oRA       = ycounter[3:1];          // 200 resolution
  assign oAddr     = yaddr + xcounter[9:4]; // advance each 16 pixels

  wire [3:0] glyphMaxY = { iGlyphMaxY, 1'b1 };

  always @(posedge iClk25) begin
    if (cmp_xmax) begin
      if ((ycounter[3:0] & glyphMaxY) == glyphMaxY) begin
        yaddr <= yaddr + 14'd40;
      end
      if (cmp_ymax) begin
        yaddr <= 0;
      end
    end
  end

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
      ycounter <= ycounter + 10'd1;
      if (cmp_ymax) begin
        yblank   <= 0;
        ycounter <= 0;
      end
    end
  end

endmodule


module video_ram_ega(
    input             iClk,       // cpu read/write clock
    input             iClk25,     // vga read clock

    // cpu write port
    input      [13:0] iCpuAddr,   // 0..16k
    input      [ 3:0] iWr,
    input      [31:0] iWrData,
    output reg [31:0] oRdData,

    // vga read port
    input      [13:0] iVgaAddr,   // 0..16k
    output reg [31:0] oVgaData
);

  reg [7:0] plane0[16384];
  reg [7:0] plane1[16384];
  reg [7:0] plane2[16384];
  reg [7:0] plane3[16384];

  //
  // cpu read/write ports
  //
  always @(posedge iClk) begin
    if (iWr[3]) begin
      plane3[ iCpuAddr ] <= iWrData[31:24];
    end else begin
      oRdData[31:24] <= plane3[ iCpuAddr ];
    end
    if (iWr[2]) begin
      plane2[ iCpuAddr ] <= iWrData[23:16];
    end else begin
      oRdData[23:16] <= plane2[ iCpuAddr ];
    end
    if (iWr[1]) begin
      plane1[ iCpuAddr ] <= iWrData[15:8];
    end else begin
      oRdData[15:8] <= plane1[ iCpuAddr ];
    end
    if (iWr[0]) begin
      plane0[ iCpuAddr ] <= iWrData[7:0];
    end else begin
      oRdData[7:0] <= plane0[ iCpuAddr ];
    end
  end

  //
  // vga read port
  //
  always @(posedge iClk25) begin
    oVgaData <= {
      plane3[ iVgaAddr ],
      plane2[ iVgaAddr ],
      plane1[ iVgaAddr ],
      plane0[ iVgaAddr ] };
  end

endmodule


module video_ega(
    input            iClk,      // cpu domain clock
    input            iClk25,    // vga domain clock

    // cpu interface
    input [19:0]     iAddr,     // read/write address
    input [ 7:0]     iWrData,   // write io/mem data
    input            iWrMem,    // memory write
    input            iRdMem,    // memory read
    input            iWrIo,     // io write
    input            iRdIo,     // io read
    output reg [7:0] oRdData,   // read io/mem data
    output reg       oSel = 0,  // read data valid

    // VGA interface
    output [3:0]     oVgaR,
    output [3:0]     oVgaG,
    output [3:0]     oVgaB,
    output           oVgaHs,
    output           oVgaVs,

    output reg       oActive = 0
);

  wire selected = iAddr[19:15] == 5'b1010_0; // 0xA0000..0xA7FFF

  //
  // CRTC
  //
  wire [13:0] crtcAddr;
  wire [ 2:0] crtcRa;
  wire [ 2:0] crtcDa;
  wire        crtcVs;
  wire        crtcHs;
  wire        crtcBl;
  video_crtc_ega u_video_crtc(
    .iClk25    (iClk25),
    .iGlyphMaxY(0),
    .oAddr     (crtcAddr),
    .oRA       (crtcRa),
    .oDA       (crtcDa),
    .oVgaVs    (crtcVs),
    .oVgaHs    (crtcHs),
    .oVgaBlank (crtcBl)
  );

  //
  // VRAM
  //

  reg [ 3:0] vramWr     = 0;
  reg [31:0] vramWrData = 0;

  wire [31:0] vramData;
  wire [31:0] vramRdData;
  video_ram_ega u_video_ram(
    .iClk    (iClk),        // cpu read/write clock
    .iClk25  (iClk25),      // vga read clock
    // cpu write port
    .iCpuAddr(iAddr[13:0]), // 0..16k
    .iWr     (vramWr),
    .iWrData (vramWrData),
    .oRdData (vramRdData),
    // vga read port
    .iVgaAddr(crtcAddr),    // 0..16k
    .oVgaData(vramData)
  );

  //
  // DAC pallette
  //
  reg [7:0] palette[16];
  initial $readmemh("roms/ega_palette.hex", palette);

  //
  //
  //
  reg [ 2:0] dlyCrtcDa;
  reg        dlyCrtcVs1, dlyCrtcVs0;
  reg        dlyCrtcHs1, dlyCrtcHs0;
  reg        dlyCrtcBl1, dlyCrtcBl0;

  always @(posedge iClk25) begin
    dlyCrtcDa   <= crtcDa;
    { dlyCrtcVs1, dlyCrtcVs0 } <= { dlyCrtcVs0, crtcVs };
    { dlyCrtcHs1, dlyCrtcHs0 } <= { dlyCrtcHs0, crtcHs };
    { dlyCrtcBl1, dlyCrtcBl0 } <= { dlyCrtcBl0, crtcBl };
  end

  //
  // attribute controller
  //

  wire [7:0] plane3 = vramData[31:24];
  wire [7:0] plane2 = vramData[23:16];
  wire [7:0] plane1 = vramData[15: 8];
  wire [7:0] plane0 = vramData[ 7: 0];

  wire [3:0] palIndex = {
    plane3[3'h7 ^ dlyCrtcDa],
    plane2[3'h7 ^ dlyCrtcDa],
    plane1[3'h7 ^ dlyCrtcDa],
    plane0[3'h7 ^ dlyCrtcDa]
  };

  reg  [7:0] palColor;
  wire [3:0] palIRGB = { palColor[4], palColor[2], palColor[1], palColor[0] };

  always @(posedge iClk25) begin
      palColor <= palette[ palIndex ];
  end

  //
  // vga output
  //
  
  //                                                              A         0                        5         0
  wire [3:0] outR =                            ( (palIRGB[2] ? 4'b1010 : 4'b0000) | (palIRGB[3] ? 4'b0101 : 4'b0000) );
  wire [3:0] outG = (palIRGB == 4'd6) ? 4'h5 : ( (palIRGB[1] ? 4'b1010 : 4'b0000) | (palIRGB[3] ? 4'b0101 : 4'b0000) );
  wire [3:0] outB =                            ( (palIRGB[0] ? 4'b1010 : 4'b0000) | (palIRGB[3] ? 4'b0101 : 4'b0000) );

  wire active = !dlyCrtcBl1;
  assign oVgaR  = active ? outR : 4'h0;
  assign oVgaG  = active ? outG : 4'h0;
  assign oVgaB  = active ? outB : 4'h0;
  assign oVgaHs = dlyCrtcHs1;
  assign oVgaVs = dlyCrtcVs1;

  //
  // register files
  //

  // attribute Controller registers
  reg         p3C0_ff = 0;    // 0-index, 1-data
  reg  [ 5:0] p3C0_index = 0;

  // sequencer registers
  reg  [ 7:0] p3C4_index = 0;
  reg  [ 7:0] p3C4_2 = 8'hff; // Graphics: Bit Mask Register

  // graphics controller registers
  reg  [ 7:0] p3CE_index = 0;
  reg  [ 7:0] p3CE_0 = 0;     // Graphics: Set/Reset Register
  reg  [ 7:0] p3CE_1 = 0;     // Graphics: Enable Set/Reset Register
  reg  [ 7:0] p3CE_2 = 0;     // Graphics: Color Compare Register
  reg  [ 7:0] p3CE_3 = 0;     // Graphics: Data Rotate
  reg  [ 7:0] p3CE_4 = 0;     // Graphics: Read Map Select Register
  reg  [ 7:0] p3CE_5 = 0;     // Graphics: Mode Register
  reg  [ 7:0] p3CE_7 = 0;     // Graphics: Color Don't Care Register
  reg  [ 7:0] p3CE_8 = 0;     // Graphics: Bit(map) Mask Register

  // data read latches
  reg  [ 7:0] latch3 = 0;
  reg  [ 7:0] latch2 = 0;
  reg  [ 7:0] latch1 = 0;
  reg  [ 7:0] latch0 = 0;
  wire [31:0] latch32 = { latch3, latch2, latch1, latch0 };

  wire [ 1:0] writeMode     = p3CE_5[1:0];
  wire        readMode      = p3CE_5[3];
  wire [ 1:0] readPlane     = p3CE_4[1:0];
  wire [ 3:0] writePlanes   = p3C4_2[3:0];
  wire [ 2:0] rotate        = p3CE_3[2:0];
  wire [ 1:0] aluFunc       = p3CE_3[4:3];
  wire [ 7:0] mapMask       = p3CE_8;
  wire [ 3:0] colorDontCare = p3CE_7[3:0];
  wire [ 3:0] colorCompare  = p3CE_2[3:0];
  wire [ 3:0] setReset      = p3CE_0[3:0];

  // write mode 2 bit broadcast
  wire [ 7:0] bc3  = iWrData[3] ? 8'hff : 8'h00;
  wire [ 7:0] bc2  = iWrData[2] ? 8'hff : 8'h00;
  wire [ 7:0] bc1  = iWrData[1] ? 8'hff : 8'h00;
  wire [ 7:0] bc0  = iWrData[0] ? 8'hff : 8'h00;
  wire [31:0] bc32 = { bc3, bc2, bc1, bc0 };

  // set/reset bits
  wire [ 7:0] sr3  = setReset[3] ? 8'hff : 8'h00;
  wire [ 7:0] sr2  = setReset[2] ? 8'hff : 8'h00;
  wire [ 7:0] sr1  = setReset[1] ? 8'hff : 8'h00;
  wire [ 7:0] sr0  = setReset[0] ? 8'hff : 8'h00;

  // color compare broadcast
  wire [ 7:0] cc3  = colorCompare[3] ? 8'hff : 8'h00;
  wire [ 7:0] cc2  = colorCompare[2] ? 8'hff : 8'h00;
  wire [ 7:0] cc1  = colorCompare[1] ? 8'hff : 8'h00;
  wire [ 7:0] cc0  = colorCompare[0] ? 8'hff : 8'h00;

  // color compare bit differences
  reg  [ 7:0] cd3  = colorDontCare[3] ? 8'd0 : (cc3 ^ latch3);
  reg  [ 7:0] cd2  = colorDontCare[2] ? 8'd0 : (cc2 ^ latch2);
  reg  [ 7:0] cd1  = colorDontCare[1] ? 8'd0 : (cc1 ^ latch1);
  reg  [ 7:0] cd0  = colorDontCare[0] ? 8'd0 : (cc0 ^ latch0);

  //
  reg  [ 7:0] dataRot  = 0;
  reg  [31:0] srMux    = 0;
  reg  [31:0] aluRes   = 0;
  reg  [31:0] writeMux = 0;
  reg         dlyWr    = 0;

  //
  // VRAM write data path
  //

  always @(*) begin

    // barrel shifter
    case (rotate)
    default: dataRot = iWrData;
    3'd1: dataRot = { iWrData[  0], iWrData[7:1] };
    3'd2: dataRot = { iWrData[1:0], iWrData[7:2] };
    3'd3: dataRot = { iWrData[2:0], iWrData[7:3] };
    3'd4: dataRot = { iWrData[3:0], iWrData[7:4] };
    3'd5: dataRot = { iWrData[4:0], iWrData[7:5] };
    3'd6: dataRot = { iWrData[5:0], iWrData[7:6] };
    3'd7: dataRot = { iWrData[6:0], iWrData[7]   };
    endcase

    // set/reset mux
    srMux = (writeMode == 2'd2) ? bc32 : {
        p3CE_1[3] ? sr3 : dataRot,
        p3CE_1[2] ? sr2 : dataRot,
        p3CE_1[1] ? sr1 : dataRot,
        p3CE_1[0] ? sr0 : dataRot
    };

    // ALU
    case (aluFunc)
    default: aluRes = srMux;
    2'd1:    aluRes = srMux & latch32;
    2'd2:    aluRes = srMux | latch32;
    2'd2:    aluRes = srMux ^ latch32;
    endcase

    // map mask bit blending
    writeMux = (writeMode == 2'd1) ? latch32 : {
      (aluRes[31:24] & mapMask) | (latch3 & ~mapMask),
      (aluRes[23:16] & mapMask) | (latch2 & ~mapMask),
      (aluRes[15: 8] & mapMask) | (latch1 & ~mapMask),
      (aluRes[ 7: 0] & mapMask) | (latch0 & ~mapMask)
    };
  end

  always @(posedge iClk) begin

    oSel <= 0;

    //
    // IO read
    //

    if (iRdIo) begin
      if (iAddr[11:0] == 12'h3DA) begin
        p3C0_ff <= 0;
        oRdData <= 8'hff;
        oSel    <= 1;
      end
    end

    //
    // IO write
    //

    if (iWrIo) begin

      // video mode enable hack
      if (iAddr[11:0] == 12'h0fe) begin
        oActive <= iWrData == 8'hd;
      end

      if (iAddr[11:0] == 12'h3c0) begin
        if (p3C0_ff == 0) begin
          p3C0_index <= iWrData[5:0];
        end else begin
          if (p3C0_index[5:4] == 2'd0) begin
            palette[ p3C0_index[3:0] ] <= iWrData;
          end
        end
        p3C0_ff <= !p3C0_ff;
      end

      if (iAddr[11:0] == 12'h3C4) begin
        p3C4_index <= iWrData;
      end
      if (iAddr[11:0] == 12'h3C5) begin
        case (p3C4_index)
        8'd2: p3C4_2 <= iWrData;
        endcase
      end

      if (iAddr[11:0] == 12'h3CE) begin
        p3CE_index <= iWrData;
      end
      if (iAddr[11:0] == 12'h3CF) begin
        case (p3CE_index)
        8'd0: p3CE_0 <= iWrData;
        8'd1: p3CE_1 <= iWrData;
        8'd2: p3CE_2 <= iWrData;
        8'd3: p3CE_3 <= iWrData;
        8'd4: p3CE_4 <= iWrData;
        8'd5: p3CE_5 <= iWrData;
        8'd7: p3CE_7 <= iWrData;
        8'd8: p3CE_8 <= iWrData;
        endcase
      end

    end

    //
    // MEM read
    //

    if (iRdMem & selected) begin

      // note: iRdAddr settled one clock ago, and so our vramRdData
      //       will already be addressing correctly.

      { latch3, latch2, latch1, latch0 } <= vramRdData;

      case (readMode)
      1'd0: begin
        // plane select read mode
        case (readPlane)
        4'd3: oRdData <= vramRdData[31:24];
        4'd2: oRdData <= vramRdData[23:16];
        4'd1: oRdData <= vramRdData[15: 8];
        4'd0: oRdData <= vramRdData[ 7: 0];
        endcase
      end
      1'd1: begin
        // color compare read mode
        // accumulate mismatches and invert
        oRdData <= ~(cd3 | cd2 | cd1 | cd0);
      end
      endcase

      oSel <= 1;
    end

    //
    // MEM write
    //

    dlyWr      <= iWrMem & selected;
    vramWr     <= dlyWr ? writePlanes : 4'd0;
    vramWrData <= writeMux;
  end

endmodule
