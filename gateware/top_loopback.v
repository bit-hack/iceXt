/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "config.vh"


module top(
    input         clk25,
    input         sw_rst,
    output        serial_tx,
    input         serial_rx,

    output [ 7:0] pmod,
`ifdef DISABLED
    input         sd_do,
    output        sd_di,
    output        sd_clk,
    output        sd_cs,
    output        led_io,
`endif
    output        pit_spk
);

  //
  //
  //

  wire pitClkEn;
  pitClock uPitClock(
    /*input     */.iClk     (pll_clk10),
    /*output reg*/.oClkEnPit(pitClkEn)
  );

  //
  // clock pll
  //

  wire pll_clk10;
  wire pll_clk25;
  wire pll_locked;
  pll u_pll(
    .clkin  (clk25),     // 25 MHz
    .clkout0(pll_clk10), // 10 MHz
    .clkout1(pll_clk25), // 25 MHz
    .locked (pll_locked)
  );

  //
  wire [7:0] uart_rx;
  wire       uart_valid;
  uartRx uUartRx(
    /*input        */.iClk  (pll_clk10),
    /*input        */.iRx   (serial_rx),
    /*output [7:0] */.oData (uart_rx),
    /*output reg   */.oValid(uart_valid),
    /*output       */.oBusy ()
  );

  localparam WIDTH = 20;
  reg [WIDTH-1:0] shift = 0;
  reg wr = 0;
  always @(posedge pll_clk10) begin
    wr <= 0;
    if (uart_valid) begin
      shift <= { shift[WIDTH-8:0], uart_rx[6:0] };
      wr <= uart_rx[7];
    end
  end

  wire [11:0] port = shift[19:8];
  wire [ 7:0] data = shift[ 7:0];
  wire pitChan0;
  wire pitChan2;
  pit2 uPit(
    /*input        */.iClk  (pll_clk10),
    /*input        */.iClkEn(pitClkEn),  // 1.193182Mhz
    /*input [7:0]  */.iData (data),
    /*input [11:0] */.iAddr (port),
    /*input        */.iWr   (wr),
    /*input        */.iRd   (1'b0),
    /*input        */.iGate2(port61gate),  // pit spk enable
    /*output       */.oOut0 (pitChan0),
    /*output       */.oOut2 (pitChan2),
    /*output [7:0] */.oData (),
    /*output reg   */.oSel  ()
  );

  assign pit_spk = port61enable & pitChan2;

  wire port61gate   = port61[0];
  wire port61enable = port61[1];
  reg [7:0] port61 = 0;
  always @(posedge pll_clk10) begin
    if (port == 12'h61) begin
      port61 <= data;
    end
  end

`ifdef DISABLED
  reg [13:0] shift = 0;
  reg        send  = 0;
  reg        cs    = 0;
  always @(posedge pll_clk10) begin
    if (spi_taken) begin
      send <= 0;
    end
    if (uart_valid) begin
      shift <= { shift[6:0], uart_rx[6:0] };
      send  <= uart_rx[7];
      if (uart_rx[7]) begin
        cs <= shift[1];
      end
    end
  end

  assign sd_di  = spi_mosi;
  assign sd_clk = spi_sck;
  assign sd_cs  = cs;

  wire       spi_sck;
  wire       spi_mosi;
  wire       spi_miso = sd_do;
  wire [7:0] spi_rx;
  wire       spi_valid;
  wire       spi_busy;
  wire       spi_taken;
  spiMaster uSpiMaster(
    /*input        */.iClk   (pll_clk10),
    /*input  [3:0] */.iClkDiv(4'd15),
    /*input        */.iSend  (send),
    /*input  [7:0] */.iData  (shift[7:0]),
    /*output [7:0] */.oData  (spi_rx),
    /*output reg   */.oAvail (spi_valid),
    /*output reg   */.oTaken (spi_taken),
    /*output       */.oBusy  (spi_busy),
    /*output       */.oMosi  (spi_mosi),
    /*input        */.iMiso  (spi_miso),
    /*output reg   */.oSck   (spi_sck)
  );

  uartTx uUartTx(
    /*input            */.iClk  (pll_clk10),
    /*input            */.iRst  (0),
    /*input      [7:0] */.iData (spi_rx),
    /*input            */.iStart(spi_valid),
    /*output reg       */.oTx   (serial_tx),
    /*output           */.oBusy (),
    /*output           */.oReady(),
    /*output reg       */.oTaken()
  );
`endif  // DISABLED

  //
  // PMOD
  //
  assign pmod = {
    /*6*/1'b0,
    /*4*/1'b0,
    /*2*/pitChan2,
    /*0*/pitClkEn,
    /*7*/1'b0,
    /*5*/1'b0,
    /*3*/1'b0,
    /*1*/pitChan0
  };

endmodule
