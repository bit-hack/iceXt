`default_nettype none

module reset (
    input  iClk,
    input  iReset,
    output oReset   // active high
);
  parameter BITS = 8;
  reg [BITS-1:0] rstCnt = 0;
  wire rst = ~&rstCnt;
  always @(posedge iClk) begin
    rstCnt <= iReset ? 0 : (rstCnt + rst);
  end
  assign oReset = rst;
endmodule
