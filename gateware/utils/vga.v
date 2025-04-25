`default_nettype none

// 640x400@70hz
module vgaGen (
    input              iClk,    // 25.175Mhz
    output wire        oHSync,  // horizontal sync
    output wire        oVSync,  // vertical sync
    output wire [15:0] oAddr,   // 320x200
    output wire        oBlank   // blanking period
);

  localparam xvis = 640;
  localparam xsyncs = xvis + 16;
  localparam xsynce = xsyncs + 96;
  localparam xmax = 800;
  localparam xpol = 0;  // negative

  localparam yvis = 400;
  localparam ysyncs = yvis + 12;
  localparam ysynce = ysyncs + 2;
  localparam ymax = 449;
  localparam ypol = 1;  // positive

  reg [9:0] x;
  reg [9:0] y;
  reg       xblank;
  reg       yblank;
  reg       xsync;
  reg       ysync;

  assign oHSync = delay[2];
  assign oVSync = delay[1];
  assign oBlank = delay[0];
  assign oAddr  = yaddr + x[9:1];

  wire [ 9:0] x_add_one = x + 10'd1;
  wire [ 9:0] y_add_one = y + 10'd1;

  reg  [15:0] yaddr = 0;

  // delay sync signals so the address precedes them by one clock.
  reg  [ 2:0] delay;
  always @(posedge iClk) begin
    delay <= {xsync, ysync, xblank | yblank};
  end

  always @(posedge iClk) begin
    if (x_add_one == xmax) begin
      x <= 10'd0;
      if (y_add_one == ymax) begin
        y     <= 10'd0;
        yaddr <= 16'd0;
      end else begin
        y     <= y_add_one;
        yaddr <= yaddr + (y[0] ? (xvis[15:1]) : 16'd0);
      end
    end else begin
      x <= x_add_one;
    end
  end

  always @(posedge iClk) begin
    case (x_add_one)
      xvis:   xblank <= 1;
      xsyncs: xsync <= xpol;
      xsynce: xsync <= !xpol;
      xmax:   xblank <= 0;
    endcase
  end

  always @(posedge iClk) begin
    case (y_add_one)
      yvis:   yblank <= 1;
      ysyncs: ysync <= ypol;
      ysynce: ysync <= !ypol;
      ymax:   yblank <= 0;
    endcase
  end

endmodule