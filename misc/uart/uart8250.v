/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module uart8250(
  input             iClk,
  input      [19:0] iAddr,
  input             iWr,
  input       [7:0] iWrData,
  input             iRd,
  output reg  [7:0] oRdData,
  output reg        oSel,

  output reg        oIntr,     // uart interrupt asserted

  input  wire [7:0] iRxData,
  input  wire       iRx,
  output wire       oRxReady,  // uart ready to accept rx data
  output reg        oRxTaken,  // uart has accepted rx data

  input  wire       iTxReady,  // cpu ready to accept tx data
  output wire [7:0] oTxData,
  output wire       oTx,

  output wire       oDTR       // modem DTR signal
);

  wire selected = { iAddr[11:3], 3'd0 } == 12'h3F8;

  reg [7:0] RBR = 0;       // rx buffer
  reg [7:0] THR = 0;       // tx buffer
  reg [3:0] IER = 0;       // int. enable
  reg [2:0] IIR = 3'b001;  // int. ident
  reg [7:0] LCR = 0;       // line ctrl.
  reg [4:0] MCR = 0;       // modem ctrl.
  reg [6:0] LSR = 0;       // line status
  reg [7:0] MSR = 0;       // modem status
  reg [7:0] SCR = 0;       // scratch
  reg [7:0] DLL = 0;       // divisor lsb
  reg [7:0] DLM = 0;       // divisor msb

  // IER 8'b0000MRTA
  //               ^--- data received available
  //              ^---- THR empty
  //             ^----- receiver line status
  //            ^------ modem status

  // IIR 3'bBBP
  //          ^-------- 0-intr. pending
  //        ^^--------- intr. ID

  wire DLAB = LCR[7];
  wire DTR  = MCR[0];  // data terminal ready
  wire RTS  = MCR[1];  // request to send
  wire DR   = LSR[0];  // rx available
  wire THRE = LSR[5];  // tx holding register empty
  wire TEMT = LSR[6];  // tx empty

  assign oRxReady = !DR;
  assign oDTR     = DTR;

  always @(posedge iClk) begin

    oSel     <= 1'b0;
    oIntr    <= 1'b0;
    oTx      <= 1'b0;
    oRxTaken <= 1'b0;

    //
    // TX/RX logic
    //

    if (iRx) begin
      LSR[0]   <= 1'b1;     // DR<=1
      RBR      <= iRxData;  // latch received data
      oRxTaken <= 1'b1;
    end

    if (iTxReady && !TEMT) begin
      LSR[5]  <= 1'b1;    // drain THRE
      LSR[6]  <= 1'b1;    // drain TEMT
      oTx     <= 1;
      oTxData <= THR;
    end

    //
    // interrupt logic
    //

    // priority 3 (lower)
    if (IER[1] & !THRE) begin
      oIntr <= 1'b1;
      IRR   <= 3'b010;  // tx buffer empty
    end
    // priority 2 (higher)
    if (IER[0] & DR) begin
      oIntr <= 1'b1;
      IIR   <= 3'b100;  // data received
    end
    
    //
    // write logic
    //
  
    if (selected & iWr) begin
      case (iAddr[2:0])
      3'd0:
        if (DLAB) begin
          DLM <= iWrData;
        end else begin
          THR    <= iWrData;
          LSR[5] <= 0;  // THRE
          LSR[6] <= 0;  // TEMT
          if (IIR == 3'b010) begin
            IIR <= 3'b001;  // clear intr.
          end
        end
      3'd1: IER <= iWrData[3:0];
      3'd3: LCR <= iWrData;
      3'd4: MCR <= iWrData[4:0];
      3'd5: LSR <= iWrData[6:0];
      3'd6: MSR <= iWrData;
      3'd7: SCR <= iWrData;
      endcase
    end

    //
    // read logic
    //

    if (selected & iRd) begin
      oRdData <= 8'hff;  // fallback value
      oSel    <= 1'b1;   // selected strobe
      case (iAddr[2:0])
      3'd0:
        if (DLAB) begin
          oRdData <= DLL;
        end else begin
          oRdData <= RBR;
          LSR[0]  <= 1'b0;  // DA
          if (IIR == 3'b100) begin
            IIR <= 3'b001;  // clear intr.
          end          
        end
      3'd1:
        if (DLAB) begin
          oRdData <= DLM;
        end else begin
          oRdData <= { 4'b0000, IER[3:0] };
        end
      3'd2: begin
        oRdData <= { 5'b00000, IIR[2:0] };
        if (IIR == 3'b010) begin
          IIR <= 3'b001;  // clear intr.
        end
      end
      3'd3: oRdData <= LCR;
      3'd4: oRdData <= { 3'b000, MCR[4:0] };
      3'd5: oRdData <= { 1'b0,   LSR[6:0] };
      3'd6: begin
        oRdData <= MSR;
        if (IIR == 3'b000) begin
          IIR <= 3'b001;  // clear intr.
        end
      end
      3'd7: oRdData <= SCR;
      endcase
    end
  end

endmodule
