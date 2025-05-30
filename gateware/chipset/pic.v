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
  input        iIrq4,     // com1
  input        iIntAck,   // cpu->pic int ack
  output       oInt,      // cpu<-pic int req
  output       oSel,
  output [7:0] oData
);

  // todo: mask
  //       end of interrupt

  reg [7:0] isr = 0;  // in service
  reg [7:0] irr = 0;  // pending
  reg       sel = 0;  // pic selected
  reg [7:0] vec = 0;  // vector code

  wire [7:0] top =      // priority
  //            76543210
    irr[0] ? 8'b00000001 :
    irr[1] ? 8'b00000010 :
    irr[4] ? 8'b00010000 :
             8'b00000000;

  wire [7:0] code =     // intr to code
    isr[0] ? 8'd8  :    // timer
    isr[1] ? 8'd9  :    // keyboard
    isr[4] ? 8'd12 :    // uart
             8'd0;

  wire [7:0] irq  = { 3'b000, iIrq4, 2'b00, iIrq1, iIrq0 };
  wire [7:0] irqe = (irq ^ irqd) & irq;   // IRQ positive edges
  reg  [7:0] irqd;                        // IRQ delay

  always @(posedge iClk) begin

    sel  <= 0;
    irqd <= irq;

    if (iIntAck) begin
      // clear before latching new interrupt
      isr <= isr ? 0 : top;
      vec <= code;
      sel <= 1;
    end

    // latch new state and clear ack'd state
    irr <= irqe | (irr & ~isr);

    // handle resets
    if (iRst) begin
      irr <= 8'd0;
      isr <= 8'd0;
      vec <= 8'd0;
    end
  end

  assign oData = vec;
  assign oSel  = sel;
  assign oInt  = |irr;

endmodule
