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

module scancode_converter(
    input            iClk,
    input            iKeyUp,
    input            iStart,
    input      [7:0] iCode,
    output           oAvail,
    output reg [7:0] oCode);

    reg avail = 0;
    assign oAvail = avail;

    always @(posedge iClk) begin
      avail <= 0;
      if (iStart) begin
        case (iCode)
        8'h0E: oCode <= 8'h29;
        8'h16: oCode <= 8'h02;
        8'h1E: oCode <= 8'h03;
        8'h26: oCode <= 8'h04;
        8'h25: oCode <= 8'h05;
        8'h2E: oCode <= 8'h06;
        8'h36: oCode <= 8'h07;
        8'h3D: oCode <= 8'h08;
        8'h3E: oCode <= 8'h09;
        8'h46: oCode <= 8'h0A;
        8'h45: oCode <= 8'h0B;
        8'h4E: oCode <= 8'h0C;
        8'h55: oCode <= 8'h0D;
        8'h66: oCode <= 8'h0E;
        8'h0D: oCode <= 8'h0F;
        8'h15: oCode <= 8'h10;
        8'h1D: oCode <= 8'h11;
        8'h24: oCode <= 8'h12;
        8'h2D: oCode <= 8'h13;
        8'h2C: oCode <= 8'h14;
        8'h35: oCode <= 8'h15;
        8'h3C: oCode <= 8'h16;
        8'h43: oCode <= 8'h17;
        8'h44: oCode <= 8'h18;
        8'h4D: oCode <= 8'h19;
        8'h54: oCode <= 8'h1A;
        8'h5B: oCode <= 8'h1B;
        8'h58: oCode <= 8'h3A;
        8'h1C: oCode <= 8'h1E;
        8'h1B: oCode <= 8'h1F;
        8'h23: oCode <= 8'h20;
        8'h2B: oCode <= 8'h21;
        8'h34: oCode <= 8'h22;
        8'h33: oCode <= 8'h23;
        8'h3B: oCode <= 8'h24;
        8'h42: oCode <= 8'h25;
        8'h4B: oCode <= 8'h26;
        8'h4C: oCode <= 8'h27;
        8'h52: oCode <= 8'h28;
        8'h5A: oCode <= 8'h1C;
        8'h12: oCode <= 8'h2A;
        8'h1A: oCode <= 8'h2C;
        8'h22: oCode <= 8'h2D;
        8'h21: oCode <= 8'h2E;
        8'h2A: oCode <= 8'h2F;
        8'h32: oCode <= 8'h30;
        8'h31: oCode <= 8'h31;
        8'h3A: oCode <= 8'h32;
        8'h41: oCode <= 8'h33;
        8'h49: oCode <= 8'h34;
        8'h4A: oCode <= 8'h35;
        8'h59: oCode <= 8'h36;
        8'h14: oCode <= 8'h1D;
        8'h11: oCode <= 8'h38;
        8'h29: oCode <= 8'h39;
        8'h77: oCode <= 8'h45;
        8'h6C: oCode <= 8'h47;
        8'h6B: oCode <= 8'h4B;
        8'h69: oCode <= 8'h4F;
        8'h75: oCode <= 8'h48;
        8'h73: oCode <= 8'h4C;
        8'h72: oCode <= 8'h50;
        8'h70: oCode <= 8'h52;
        8'h7C: oCode <= 8'h37;
        8'h7D: oCode <= 8'h49;
        8'h74: oCode <= 8'h4D;
        8'h7A: oCode <= 8'h51;
        8'h71: oCode <= 8'h53;
        8'h7B: oCode <= 8'h4A;
        8'h79: oCode <= 8'h4E;
        8'h76: oCode <= 8'h01;
        8'h05: oCode <= 8'h3B;
        8'h06: oCode <= 8'h3C;
        8'h04: oCode <= 8'h3D;
        8'h0C: oCode <= 8'h3E;
        8'h03: oCode <= 8'h3F;
        8'h0B: oCode <= 8'h40;
        8'h83: oCode <= 8'h41;
        8'h0A: oCode <= 8'h42;
        8'h01: oCode <= 8'h43;
        8'h09: oCode <= 8'h44;
        8'h78: oCode <= 8'h57;
        8'h07: oCode <= 8'h58;
        8'h7E: oCode <= 8'h46;
        8'h5D: oCode <= 8'h2B;
        default: oCode <= 8'h00;
        endcase
        if (iKeyUp) begin
          oCode[7] <= 1'b1;
        end
        avail <= 1;
      end
    end
endmodule

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
  reg        sel        = 0;

  // falling clock edge
  wire shift_in = ps2ClkSync[3] == 1 && ps2ClkSync[2] == 0;

  // sync ps/2 clock and data
  always @(posedge iClk) begin
    ps2ClkSync <= { ps2ClkSync[2:0], iPs2Clk };
    ps2DatSync <= { ps2DatSync[2:0], iPs2Dat };
  end

  reg ps2_avail = 0;

  always @(posedge iClk) begin

    ps2_avail <= 0;
    timeout   <= timeout + 1;

    if (shift_in) begin
      shift   <= { ps2DatSync[2], shift[10:1] };
      count   <= count + 1;
      timeout <= 0;
    end

    if (count == 4'd11) begin
      count <= 0;
      if (shift[ 0] == 0 &&     // start bit = 0
          shift[10] == 1) begin // stop bit = 1
        data      <= shift[8:1];
        ps2_avail <= 1;
      end
    end

    if (timeout == 16'hffff) begin
      count <= 0;
    end
  end

  reg        key_up = 0;
  wire       irq;
  wire [7:0] scancode;
  reg        start = 0;

  scancode_converter u_scancode_converter(
    .iClk  (iClk),
    .iKeyUp(key_up),
    .iStart(start),
    .iCode (data),
    .oAvail(irq),
    .oCode (scancode)
  );
  
  always @(posedge iClk) begin
    start <= 0;
    if (ps2_avail) begin
      if (data == 8'hf0) begin
        key_up <= 1;
      end else begin
        start <= 1;
      end
    end
    if (irq) begin
      key_up <= 0;
    end
  end

  always @(posedge iClk) begin
    sel <= 0;
    if (iRd && iAddr[11:0] == 12'h060) begin
      sel <= 1;
    end
  end
  
  assign oData = scancode;
  assign oSel  = sel;
  assign oIrq  = irq;

endmodule
