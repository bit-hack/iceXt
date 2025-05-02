/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "../config.vh"


module bios(
  input        iClk,
  input [19:0] iAddr,
  input        iRd,
  output       oSel,
  output [7:0] oData
);

  reg       bios_sel = 0;
  reg [7:0] bios_rom[8192];
  reg [7:0] bios_out = 0;

  initial $readmemh("roms/pcxtbios.hex", bios_rom);

  always @(posedge iClk) begin
    bios_sel <= 0;
    if (iRd) begin
      // [FE000 ... FFFFF]
      bios_sel <= iAddr[19:13] == 7'b1111111;
      bios_out <= bios_rom[ iAddr[12:0] ];
    end
  end

  assign oData = bios_out;
  assign oSel  = bios_sel;

endmodule
