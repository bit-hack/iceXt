`default_nettype none

module sevenSeg (
    input        clk,
    input  [7:0] value,
    output [6:0] led,
    output       sel
);

  //  .-A-.
  //  F   B
  //  +-G-+
  //  E   C
  //  '-D-'

  assign sel = count[9];
  wire [3:0] index = sel ? value[3:0] : value[7:4];

  always @(*) begin
    case (index)
      //            gfedcba
      'h0: led = 7'b1000000;  // 0
      'h1: led = 7'b1111001;  // 1
      'h2: led = 7'b0100100;  // 2
      'h3: led = 7'b0110000;  // 3
      'h4: led = 7'b0011001;  // 4
      'h5: led = 7'b0010010;  // 5
      'h6: led = 7'b0000011;  // 6
      'h7: led = 7'b1111000;  // 7
      'h8: led = 7'b0000000;  // 8
      'h9: led = 7'b0011000;  // 9
      'ha: led = 7'b0001000;  // A
      'hb: led = 7'b0000011;  // B
      'hc: led = 7'b1000110;  // C
      'hd: led = 7'b0100001;  // D
      'he: led = 7'b0000100;  // E
      'hf: led = 7'b0001110;  // F
    endcase
  end

  reg [9:0] count;
  always @(posedge clk) begin
    count <= count + 1;
  end

endmodule
