/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module pit2(
    input        iClk,
    input        iClkEn,  // 1.193182Mhz
    input [7:0]  iData,
    input [11:0] iAddr,
    input        iWr,
    input        iRd,
    input        iGate2,  // pit spk enable
    output       oOut0,
    output       oOut2,
    output [7:0] oData,
    output reg   oSel = 0
);

  // iAddr is 0x40/0x41/0x42/0x43
  wire selected = ({ iAddr[11:2], 2'b00 } == 12'h040);

  always @(posedge iClk) begin
    oSel <= 0;
    if (iRd) begin
      oSel <= selected;
    end
  end

  wire [7:0] data0;
  pit_counter #(.INDEX(2'd0)) u_ce_0 (
    .iClk   (iClk),
    .iClkEn (iClkEn),
    .iAddr  (iAddr[1:0]),
    .iData  (iData),
    .iWr    (iWr & selected),
    .iRd    (iRd & selected),
    .iGate  (1'b1),
    .oOut   (oOut0),
    .oData  (data0)
  );

  wire [7:0] data1;
  pit_counter #(.INDEX(2'd2)) u_ce_2 (
    .iClk   (iClk),
    .iClkEn (iClkEn),
    .iAddr  (iAddr[1:0]),
    .iData  (iData),
    .iWr    (iWr & selected),
    .iRd    (iRd & selected),
    .iGate  (iGate2),
    .oOut   (oOut2),
    .oData  (data1)
  );

  assign oData = data0 | data1;

endmodule

module pit_counter (
    input            iClk,
    input            iClkEn,
    input      [1:0] iAddr,
    input      [7:0] iData,
    input            iWr,
    input            iRd,
    input            iGate,
    output reg       oOut  = 0,
    output reg [7:0] oData = 0
);

  parameter INDEX = 2'b0;

  reg [15:0] reload  = 16'h0020;  // reload value
  reg [15:0] counter = 16'h0020;  // current counter value
  reg [15:0] latch   = 0;         // read latch register
  reg [ 1:0] freeze  = 0;         // latch byte freeze
  reg [ 2:0] mode    = 0;         // counter mode
  reg [ 1:0] lut     = 0;         // register index lut

  wire is_mode_3   = (mode[1:0] == 2'b11);
  wire is_terminal = is_mode_3 ? (counter[15:1] == 15'd0) : 1'b0;

  always @(posedge iClk) begin

    oData <= 8'd0;

    //
    // counter logic
    //

    if (iClkEn) begin

      latch[15:8] <= freeze[1] ? latch[15:8] : counter[15:8];
      latch[ 7:0] <= freeze[0] ? latch[ 7:0] : counter[ 7:0];

      case(1'b1)
      (is_mode_3 & iGate): begin
        counter <= (is_terminal ? reload : counter) - ((counter[0] & oOut) ? 16'd1 : 16'd2);
        oOut    <=  is_terminal ? ~oOut : oOut;
      end
      endcase
    end

    //
    // write port logic
    //

    if (iWr) begin

      // write to reload register CRm and CRl
      if (iAddr == INDEX) begin
        reload <= { (lut[0]==1) ? iData : reload[15:8],
                    (lut[0]==0) ? iData : reload[ 7:0] };
        lut    <= { lut[0], lut[1] };
      end

      // write to control register
      if (iAddr == 2'd3) begin
        if (iData[7:6] == INDEX) begin

          // reload type
          case (iData[5:4])
          2'b00: begin
            freeze <= 2'b11;
            lut    <= (lut == 2'b01) ? 2'b10 : lut;  // restore order
          end
          2'b01: lut <= 2'b00;  // LSB
          2'b10: lut <= 2'b11;  // MSB
          2'b11: lut <= 2'b10;  // LSB/MSB
          endcase

          // update counter mode
          mode <= iData[3:1];
        end
      end
    end

    //
    // read port logic
    //

    if (iRd) begin
      // read from the latch register OLm and OLl
      if (iAddr == INDEX) begin
        oData  <= (lut[0]==0) ? latch[7:0] : latch[15:8];
        lut    <= { lut[0], lut[1] };
        freeze <= { (lut[0]==1) ? 1'b0 : freeze[1],
                    (lut[0]==0) ? 1'b0 : freeze[0] };
      end
    end
  end

endmodule
