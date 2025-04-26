`default_nettype none

// 4k of RAM at address 0x0B0000
// the entire 32k from 0B0000h to 0B7FFFh is filled with repeats of this 4k area.
// I/O addresses 03B0h-03BFh
// MC6845
// 80*25*2
// display resolution of the MDA is 720 × 350 pixels
// layout <char><attr><char><attr><char><attr>...
// 8x16 font at 1x2 scale for 640x400.

`default_nettype none

// 640x400@70hz
module vga_gen(
    input              iClk25,  // 25.175Mhz
    output wire        oHSync,  // horizontal sync
    output wire        oVSync,  // vertical sync
    output wire [15:0] oAddr,   // 80x25 addr
    output wire [ 2:0] oX,      // 0..7
    output wire [ 2:0] oY,      // 0..7
    output wire        oBlank   // blanking period
);

  localparam xvis   = 640;
  localparam xsyncs = xvis   + 16;
  localparam xsynce = xsyncs + 96;
  localparam xmax   = 800;
  localparam xpol   = 0;  // negative

  localparam yvis   = 400;
  localparam ysyncs = yvis   + 12;
  localparam ysynce = ysyncs + 2;
  localparam ymax   = 449;
  localparam ypol   = 1;  // positive

  reg [9:0] x;
  reg [9:0] y;
  reg       xblank;
  reg       yblank;
  reg       xsync;
  reg       ysync;

  assign oHSync = delay[2];
  assign oVSync = delay[1];
  assign oBlank = delay[0];
  assign oAddr  = yaddr + x[9:3];
  assign oX     = x[2:0];
  assign oY     = y[2:0];

  wire [9:0] x_add_one = x + 10'd1;
  wire [9:0] y_add_one = y + 10'd1;

  reg [15:0] yaddr = 0;

  // delay sync signals so the address precedes them by one clock.
  reg [2:0] delay;
  always @(posedge iClk25) begin
    delay <= {xsync, ysync, xblank | yblank};
  end

  always @(posedge iClk25) begin
    if (x_add_one == xmax) begin
      x <= 10'd0;
      if (y_add_one == ymax) begin
        y     <= 10'd0;
        yaddr <= 16'd0;
      end else begin
        y     <= y_add_one;
        yaddr <= yaddr + (y[2:0]==3'd7 ? 16'd80 : 16'd0);
      end
    end else begin
      x <= x_add_one;
    end
  end

  always @(posedge iClk25) begin
    case (x_add_one)
    xvis:   xblank <= 1;
    xsyncs: xsync  <=  xpol;
    xsynce: xsync  <= !xpol;
    xmax:   xblank <= 0;
    endcase
  end

  always @(posedge iClk25) begin
    case (y_add_one)
    yvis:   yblank <= 1;
    ysyncs: ysync  <=  ypol;
    ysynce: ysync  <= !ypol;
    ymax:   yblank <= 0;
    endcase
  end
endmodule


module video_mda(
    input        iClk,      // cpu domain clock
    input        iClk25,    // vga domain clock
    input [19:0] iAddr,
    input [ 7:0] iData,
    input        iWr,
    output [3:0] oVgaR,
    output [3:0] oVgaG,
    output [3:0] oVgaB,
    output       oVgaHs,
    output       oVgaVs
);

  reg [7:0] cram[4096];  // char ram

  reg [7:0] font[16384];
  initial $readmemb("roms/font8x8.hex", font);

  reg [2:0] dly_hs;
  reg [2:0] dly_vs;
  reg [2:0] dly_blank;
  reg [2:0] dly_x0;
  reg [2:0] dly_x1;
  reg [2:0] dly_y0;
  always @(posedge iClk25) begin
    dly_hs    <= { dly_hs   [1:0], vga_hs    };
    dly_vs    <= { dly_vs   [1:0], vga_vs    };
    dly_blank <= { vga_blank[1:0], vga_blank };
    dly_x0    <= vga_x;
    dly_x1    <= dly_x0;
    dly_y0    <= vga_y;
  end

  reg [7:0] lu_chr;
  reg [7:0] lu_line;
  always @(posedge iClk25) begin
    lu_chr  <= cram[ vga_addr[11:0] ];
    lu_line <= font[ { lu_chr, dly_y0 } ];
  end

  wire        vga_hs;
  wire        vga_vs;
  wire [15:0] vga_addr;
  wire        vga_blank;
  wire [ 2:0] vga_x;
  wire [ 2:0] vga_y;
  vga_gen u_vga_gen(
    /*input              */.iClk25(iClk25),
    /*output wire        */.oHSync(vga_hs),
    /*output wire        */.oVSync(vga_vs),
    /*output wire [15:0] */.oAddr (vga_addr),
    /*output wire [ 2:0] */.oX    (vga_x),
    /*output wire [ 2:0] */.oY    (vga_y),
    /*output wire        */.oBlank(vga_blank)
  );

  // check for 0xB0000 to 0xB8000
  // B7   10110zzz
  // B8 = 10111000
  wire sel = (iAddr[19:15] == 5'b10110);

  // vram write port
  always @(posedge iClk25) begin
    if (sel & iWr) begin
      cram[ iAddr[11:0] ] <= iData;
    end
  end

  wire bit = lu_line[ dly_x1 ];
  wire [3:0] bit_val = bit ? 4'hf : 4'h0;

  assign oVgaR  = dly_blank[0] ? 4'd0 : bit_val;
  assign oVgaG  = dly_blank[0] ? 4'd0 : bit_val;
  assign oVgaB  = dly_blank[0] ? 4'd0 : bit_val;
  assign oVgaHs = dly_hs   [0];
  assign oVgaVs = dly_vs   [0];

endmodule
