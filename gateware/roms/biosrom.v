/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "../config.vh"


module biosRom(
  input        iClk,
  input [19:0] iAddr,
  input        iRd,
  output       oSel,
  output [7:0] oData
);

  reg [7:0] rom_data[8192];
  reg       rom_sel = 0;
  reg [7:0] rom_out = 0;

  initial $readmemh("roms/pcxtbios.hex", rom_data);

  always @(posedge iClk) begin
    rom_sel <= 0;
    if (iRd) begin
      // [FE000 ... FFFFF]
      rom_sel <= iAddr[19:13] == 7'b1111111;
      rom_out <= rom_data[ iAddr[12:0] ];
    end
  end

  assign oData = rom_out;
  assign oSel  = rom_sel;

endmodule
