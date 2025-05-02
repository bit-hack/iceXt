/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module pic(
  input        iClk,
  input        iRst,
  input        iIrq0,     // timer
  input        iIrq1,     // keyboard
  input        iIntAck,   // cpu->pic int ack
  output       oInt,      // cpu<-pic int req
  output       oSel,
  output [7:0] oData
);

  // todo: mask
  //       end of interrupt

  reg [1:0] isr   = 0;  // in service
  reg [1:0] irr   = 0;  // pending
  reg       sel   = 0;  // pic selected
  reg [7:0] vec   = 0;  // vector code

  wire [1:0] top =      // priority
    irr[0] ? 2'b01 :
    irr[1] ? 2'b10 :
             2'b00;

  wire [7:0] code =     // lane to code
    isr[0] ? 8'd8 :
    isr[1] ? 8'd9 :
             8'd0;

  always @(posedge iClk) begin

    sel <= 0;

    if (iIntAck) begin
      // clear before latching new interrupt
      isr <= isr ? 0 : top;
      vec <= code;
      sel <= 1;
    end

    // latch new state and clear ack'd state
    irr <= {iIrq1, iIrq0} | (irr & ~isr);

    // handle resets
    if (iRst) begin
      irr <= 2'd0;
      isr <= 2'd0;
      vec <= 8'd0;
    end
  end

  assign oData = vec;
  assign oSel  = sel;
  assign oInt  = |irr;

endmodule
