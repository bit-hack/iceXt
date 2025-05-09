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
    input         sd_do,
    output        sd_di,
    output        sd_clk,
    output        sd_cs,
    output        led_io,
    output        pit_spk
);

   assign led_io  = ~sd_clk;
   assign pit_spk = ~sd_clk;

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

  //
  // PMOD
  //
  assign pmod = {
    /*6*/1'b0,
    /*4*/1'b0,
    /*2*/spi_miso,
    /*0*/spi_sck,
    /*7*/1'b0,
    /*5*/1'b0,
    /*3*/spi_mosi,
    /*1*/cs
  };

endmodule
