/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module pic1(
  input        iClk,
  input        iRst,
  input        iIrq0,     // timer
  input        iIrq1,     // keyboard
  input        iIrq4,     // com1
  input        iIntAck,   // cpu->pic int ack
  output       oInt,      // cpu<-pic int req
  output       oSel,
  output [7:0] oData,
  output [7:0] oDebug
);

  assign oDebug = {
    3'b000,
    iIntAck,
    oInt,
    iIrq4,
    iIrq1,
    iIrq0
  };

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



module pic2(
  input            iClk,
  input            iRst,
  input            iIrq0,     // timer
  input            iIrq1,     // keyboard
  input            iIrq4,     // com1
  input            iIntAck,   // cpu->pic int ack
  input  [19:0]    iAddr,
  input  [ 7:0]    iWrData,
  input            iWr,
  input            iRd,
  output           oInt,      // cpu<-pic int req
  output reg       oSel,
  output reg [7:0] oData,
  output     [7:0] oDebug
);

  assign oDebug = {
    3'b000,
    iIntAck,
    oInt,
    iIrq4,
    iIrq1,
    iIrq0
  };

  wire sel20h = (iAddr[11:0] == 12'h020);
  wire sel21h = (iAddr[11:0] == 12'h021);

  reg [7:0] isr = 0;  // in service
  reg [7:0] irr = 0;  // pending
  reg [7:0] imr = 0;  // mask register

  reg    intr = 0;
  assign oInt = intr;

  wire [7:0] irr_top =     // priority
  //            76543210
    irr[0] ? 8'b00000001  : // timer
    irr[1] ? 8'b00000010  : // keyboard
    irr[4] ? 8'b00010000  : // uart
             8'b00000000;

  wire [7:0] isr_top =     // intr to code
  //            76543210
    isr[0] ? 8'b00000001  : // timer
    isr[1] ? 8'b00000010  : // keyboard
    isr[4] ? 8'b00010000  : // uart
             8'b00000000;

  wire [7:0] irr_code =
    irr[0] ? 8'd0  :        // timer
    irr[1] ? 8'd1  :        // keyboard
    irr[4] ? 8'd4  :        // uart
             8'd0;

  wire [7:0] irq  = { 3'b000, iIrq4, 2'b00, iIrq1, iIrq0 };
  wire [7:0] irqe   = (irq ^ irqd) & irq;   // IRQ positive edges
  reg  [7:0] irqd   = 0;                    // IRQ delay (for edge detection)
  reg        ack_ff = 0;

  // irr after latching new requests
  wire [7:0] irr_next = irr | (irqe & ~imr);

  always @(posedge iClk) begin

    oSel <= 0;

    // delay to for edge detector
    irqd <= irq;

    // assert intr if highest pending not masked by any higher being serviced
    intr <= irr_top[0] ? !|isr_top[  0] :
            irr_top[1] ? !|isr_top[1:0] :
            irr_top[4] ? !|isr_top[4:0] :
            1'b0;

    // latch new interrupts
    irr <= irr_next;

    if (iIntAck) begin
      // we get ack'd twice, the first one has to be ignored
      ack_ff <= !ack_ff;
      if (ack_ff) begin
        isr <= isr      |  irr_top;
        // lower acked interrupt
        irr <= irr_next & ~irr_top; 
        // vector code/address
        oData <= 8'd8 + irr_code;
        oSel  <= 1;
      end
    end

    if (iWr) begin
      if (sel20h) begin
        // EOI
        if (iWrData == 8'h20) begin
          // remove highest priority bit from ISR
          isr <= isr & ~isr_top;
        end
      end
      if (sel21h) begin
        imr <= iWrData;
      end
    end

    if (iRd) begin
      if (sel21h) begin
        oData <= imr;
        oSel  <= 1;
      end
    end

    // handle resets
    if (iRst) begin
      irr    <= 0;
      isr    <= 0;
      imr    <= 0;
      oData  <= 0;
      intr   <= 0;
      ack_ff <= 0;
      oSel   <= 0;
    end
  end

endmodule
