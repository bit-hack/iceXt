`default_nettype none

module ym3014(
  input               iClk,
  input               iClkEn,    // 3.58Mhz
  input signed [15:0] iSample,
  output              oDacClk,
  output              oDacLoad,
  output              oDacSd
);

  //         YM3014
  //         __  __
  //      o-|  \/  |-o
  //      o-|      |-o
  // LOAD o-|      |-o
  // SD   o-|      |-o CLOCK
  //        '------'

  reg [ 2:0] e     = 0; // exponent
  reg [15:0] s     = 0; // mantissa shifter
  reg [17:0] latch = 0; // output latch
  reg [ 6:0] count = 0; // timing counter
  reg        load  = 0;

  assign oDacSd   = latch[0];
  assign oDacClk  = count[1:0] == 2;
  assign oDacLoad = load;

  always @(posedge iClk) begin
    if (iClkEn) begin
      if (count == 0) begin
        count <= 72;
        e     <= 0;
        s     <= iSample;
        //         3   <---- 10 ----->  5 = 18bits
        latch <= { ~e, ~s[15], s[14:6], 5'd0 };
        load  <= 0;
      end else begin
        if (s[15] == s[14]) begin
          if (e != 6) begin
            e <= e + 1;
            s <= { s[14:0], 1'b0 };
          end
        end
        if (count == 36) begin
          load <= 1;
        end
        if (count[1:0] == 1) begin
          latch <= { 1'b0, latch[17:1] };
        end
        count <= count - 1;
      end
    end
  end
endmodule
