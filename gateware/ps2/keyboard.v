/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


//      ST    D0    D1    D2    D3    D4    D5    D6    D7    PR    SP
//      |     |     |     |     |     |     |     |     |     |     |
// _____    __    __    __    __    __    __    __    __    __    __    ____
//      |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|     CLK
// ___             ______      ____________    _____________________________
//    |___________|      |____|            |__|                              DAT
//
//  Clock is ~13.230Khz
//  Frame is 11 bits
//  data valid when clock is low
//  ST - always 0
//  SP - always 1
//  PR - odd parity

module ps2_keyboard(
    input        iClk,

    // CPU interface
    input [19:0] iAddr,   // cpu port addr
    input        iRd,     // port 60h read
    output       oSel,
    output [7:0] oData,
    output       oIrq,

    // external PS2 interface
    input        iPs2Clk,
    input        iPs2Dat
);

  reg [ 3:0] ps2ClkSync = 0;
  reg [ 3:0] ps2DatSync = 0;
  reg [10:0] shift      = 0;
  reg [ 3:0] count      = 0;
  reg [15:0] timeout    = 0;
  reg [ 7:0] data       = 0;
  reg        irq        = 0;
  reg        sel        = 0;

  // falling clock edge
  wire shift_in = ps2ClkSync[3] == 1 && ps2ClkSync[2] == 0;

  // sync ps/2 clock and data
  always @(posedge iClk) begin
    ps2ClkSync <= { ps2ClkSync[2:0], iPs2Clk };
    ps2DatSync <= { ps2DatSync[2:0], iPs2Dat };
  end

  always @(posedge iClk) begin

    irq     <= 0;
    timeout <= timeout + 1;

    if (shift_in) begin
      shift   <= { ps2DatSync[2], shift[10:1] };
      count   <= count + 1;
      timeout <= 0;
    end

    if (count == 4'd11) begin
      count <= 0;
      if (shift[ 0] == 0 &&     // start bit = 0
          shift[10] == 1) begin // stop bit = 1
        data <= shift[8:1];
        irq  <= 1;
      end
    end

    if (timeout == 16'hffff) begin
      count <= 0;
    end
  end

  always @(posedge iClk) begin
    sel <= 0;
    if (iRd && iAddr[11:0] == 12'h060) begin
      sel <= 1;
      // oData <= data;
    end
  end

  assign oSel  = sel;
  assign oIrq  = irq;
  assign oData = data;  // FIXME

endmodule
