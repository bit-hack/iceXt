`default_nettype none

module spiMaster(
  input        iClk,
  input  [3:0] iClkDiv,     // clock divide factor
  input        iSend,       // trigger data send
  input  [7:0] iData,       // tx data
  output [7:0] oData,       // rx data
  output reg   oAvail = 0,  // oData is available
  output reg   oTaken = 0,  // iData has been taken
  output       oBusy,       // is busy
  
  // SPI external interface
  output       oMosi,       // spi mosi
  input        iMiso,       // spi miso
  output reg   oSck = 0     // spi clock
);
  reg [3:0] div   = 0;
  reg [3:0] state = 0;
  reg [7:0] so    = 0;
  reg [7:0] si    = 0;

  assign oMosi = so[7];
  assign oData = si;
  assign oBusy = (state != 0);

  always @(posedge iClk) begin
  
    oTaken <= 0;
    oAvail <= 0;
  
    div <= (div == 0) ? iClkDiv : div - 1;

    case (state)

    // idle
    0: begin
      oSck <= 0;
      if (iSend) begin
        oTaken <= 1;
        so     <= iData;
        state  <= 1;
      end
    end

    // wait for start of cycle
    1: begin
      if (div == 0) begin
        state <= 2;
      end
    end

    // finished
    10:
      begin
        if (div == 0) begin
          oSck   <= 0;
          oAvail <= 1;
          state  <= 0;
        end
      end

    // shifting bits in / out
    default:
      if (div == 0) begin
        oSck <= ~oSck;
        if (oSck == 1) begin
          // shift out on sck negedge
          so    <= { so[6:0], 1'b1 };
        end else begin
          // sample on sck posedge
          si <= { si[6:0], iMiso };
          state <= state + 1;
        end
      end
    endcase
  end
endmodule
