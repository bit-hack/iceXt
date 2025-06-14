/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module keyboard_ctrl(
    input            iClk,

    // CPU interface
    input     [19:0] iAddr,   // cpu port addr
    input            iRd,     // port 60h read
    input            iWr,
    input      [7:0] iData,
    output reg       oSel,
    output reg [7:0] oData,
    output           oIrq,

    // PIT wires
    output           oSpkGate,
    output           oSpkEnable,

    // external PS2 interface
    input            iPs2Clk,
    input            iPs2Dat,
    output           oPs2Clk,
    output           oPs2Dat
);

  //
  // address decoding
  //

  wire sel_port60 = (iAddr[11:0] == 12'h060);
  wire sel_port61 = (iAddr[11:0] == 12'h061);

  //
  // port 61h logic
  //

  reg [7:0] port61 = 8'h00;

  assign oSpkGate       = port61[0];
  assign oSpkEnable     = port61[1];
  wire   switch_high    = port61[3];
  wire   kbd_enable     = port61[7];
  reg    kbd_enable_dly = 0;

  //
  // PS2 port logic
  //

  wire       ps2_avail;
  wire [7:0] ps2_data;
  ps2_device device0(
    .iClk    (iClk),
    .iTx     (1'b0),
    .iTxData (8'd0),
    .oTxOk   (),
    .oTxFail (),
    .iInhibit(1'b0),
    .oRx     (ps2_avail),
    .oRxData (ps2_data),
    .iPs2Clk (iPs2Clk),
    .iPs2Dat (iPs2Dat),
    .oPs2Clk (oPs2Clk),
    .oPs2Dat (oPs2Dat),
  );

  //
  // scancode translation
  //

  wire [7:0] scan0;
  scancode_converter u_scancode_conterter(
    .iCode(ps2_data),
    .oCode(scan0)
  );

  reg        E0       = 0;
  reg        F0       = 0;
  reg        valid    = 0;  // out contains data
  reg  [7:0] out      = 0;
  wire [7:0] code     = { F0, scan0[6:0] };

  always @(posedge iClk) begin

    oSel           <= 0;
    kbd_enable_dly <= kbd_enable;

    // latch next keyboard byte on keyboard enable edge
    if ((kbd_enable_dly ^ kbd_enable) & !kbd_enable) begin
      valid <= 1'b0;  // nothing else to pull in yet
    end

    if (iRd) begin
      if (sel_port60) begin
        oData <= out;
        oSel  <= 1;
      end
      if (sel_port61) begin
        oData <= port61;
        oSel  <= 1;
      end
    end

    if (iWr) begin
      if (sel_port61) begin
        port61 <= iData;
      end
    end

    if (ps2_avail) begin
      case (ps2_data)
      8'hE0: E0 <= 1'b1;
      8'hF0: F0 <= 1'b1;
      default: begin
        E0    <= 1'b0;
        F0    <= 1'b0;
        valid <= 1'b1;
        out   <= code;
      end
      endcase
    end
  end

  assign oIrq = valid;

endmodule


module scancode_converter(
    input  [7:0] iCode,
    output [7:0] oCode);

    // converts from scancode set2 to set1

    always @(*) begin
      case (iCode)
      8'h01:   oCode = 8'h43;  // F9
      8'h03:   oCode = 8'h3F;  // F5
      8'h04:   oCode = 8'h3D;  // F3
      8'h05:   oCode = 8'h3B;  // F1
      8'h06:   oCode = 8'h3C;  // F2
      8'h07:   oCode = 8'h58;  // F12
      8'h09:   oCode = 8'h44;  // F10
      8'h0A:   oCode = 8'h42;  // F8
      8'h0B:   oCode = 8'h40;  // F6
      8'h0C:   oCode = 8'h3E;  // F4
      8'h0D:   oCode = 8'h0F;  // tab
      8'h0E:   oCode = 8'h29;  // `
      8'h11:   oCode = 8'h38;  // left alt
      8'h12:   oCode = 8'h2A;  // left shift
      8'h14:   oCode = 8'h1D;  // left ctrl.
      8'h15:   oCode = 8'h10;  // Q
      8'h16:   oCode = 8'h02;  // 1
      8'h1A:   oCode = 8'h2C;  // Z
      8'h1B:   oCode = 8'h1F;  // S
      8'h1C:   oCode = 8'h1E;  // A
      8'h1D:   oCode = 8'h11;  // W
      8'h1E:   oCode = 8'h03;  // 2
      8'h21:   oCode = 8'h2E;  // C
      8'h22:   oCode = 8'h2D;  // X
      8'h23:   oCode = 8'h20;  // D
      8'h24:   oCode = 8'h12;  // E
      8'h25:   oCode = 8'h05;  // 4
      8'h26:   oCode = 8'h04;  // 3
      8'h29:   oCode = 8'h39;  // space
      8'h2A:   oCode = 8'h2F;  // V
      8'h2B:   oCode = 8'h21;  // F
      8'h2C:   oCode = 8'h14;  // T
      8'h2D:   oCode = 8'h13;  // R
      8'h2E:   oCode = 8'h06;  // 5
      8'h31:   oCode = 8'h31;  // N
      8'h32:   oCode = 8'h30;  // B
      8'h33:   oCode = 8'h23;  // H
      8'h34:   oCode = 8'h22;  // G
      8'h35:   oCode = 8'h15;  // Y
      8'h36:   oCode = 8'h07;  // 6
      8'h3A:   oCode = 8'h32;  // M
      8'h3B:   oCode = 8'h24;  // J
      8'h3C:   oCode = 8'h16;  // U
      8'h3D:   oCode = 8'h08;  // 7
      8'h3E:   oCode = 8'h09;  // 8
      8'h41:   oCode = 8'h33;  // ,
      8'h42:   oCode = 8'h25;  // K
      8'h43:   oCode = 8'h17;  // I
      8'h44:   oCode = 8'h18;  // O
      8'h45:   oCode = 8'h0B;  // 0
      8'h46:   oCode = 8'h0A;  // 9
      8'h49:   oCode = 8'h34;  // .
      8'h4A:   oCode = 8'h35;  // /
      8'h4B:   oCode = 8'h26;  // L
      8'h4C:   oCode = 8'h27;  // ;
      8'h4D:   oCode = 8'h19;  // P
      8'h4E:   oCode = 8'h0C;  // -
      8'h52:   oCode = 8'h28;  // '
      8'h54:   oCode = 8'h1A;  // [
      8'h55:   oCode = 8'h0D;  // =
      8'h58:   oCode = 8'h3A;  // caps
      8'h59:   oCode = 8'h36;  // right shift
      8'h5A:   oCode = 8'h1C;  // return
      8'h5B:   oCode = 8'h1B;  // ]
      8'h5D:   oCode = 8'h2B;  // \
      8'h66:   oCode = 8'h0E;  // backspace
      8'h69:   oCode = 8'h4F;  // keypad 1
      8'h6C:   oCode = 8'h47;  // keypad 7
      8'h6B:   oCode = 8'h4B;  // keypad 4  (ext. cursor - left)
      8'h70:   oCode = 8'h52;  // keypad 0
      8'h71:   oCode = 8'h53;  // keypad .
      8'h72:   oCode = 8'h50;  // keypad 2  (ext. cursor - down)
      8'h73:   oCode = 8'h4C;  // keypad 5
      8'h74:   oCode = 8'h4D;  // keypad 6  (ext. cursor - right)
      8'h75:   oCode = 8'h48;  // keypad 8  (ext. cursor - up)
      8'h76:   oCode = 8'h01;  // escape
      8'h77:   oCode = 8'h45;  // num (lock?)
      8'h78:   oCode = 8'h57;  // F11
      8'h79:   oCode = 8'h4E;  // keypad +
      8'h7A:   oCode = 8'h51;  // keypad 3
      8'h7B:   oCode = 8'h4A;  // keypad -
      8'h7C:   oCode = 8'h37;  // keypad *
      8'h7D:   oCode = 8'h49;  // keypad 9
      8'h7E:   oCode = 8'h46;  // scroll (lock?)
      8'h83:   oCode = 8'h41;  // F7
      default: oCode = 8'h00;
      endcase
    end
endmodule
