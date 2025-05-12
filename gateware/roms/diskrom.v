/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "../config.vh"


module diskRom(
  input        iClk,
  input [19:0] iAddr,
  input        iRd,
  output       oSel,
  output [7:0] oData
);

  reg [7:0] rom_data[2048];
  reg       rom_sel = 0;
  reg [7:0] rom_out = 0;

  initial $readmemh("roms/diskrom.hex", rom_data);

  always @(posedge iClk) begin
    rom_sel <= 0;
    if (iRd) begin
      // [C8000 ... C87FF]          ....----.
      rom_sel <= iAddr[19:11] == 9'b110010000;
      rom_out <= rom_data[ iAddr[10:0] ];
    end
  end

  assign oData = rom_out;
  assign oSel  = rom_sel;

endmodule
