`default_nettype none

module clkEnGen #(
    parameter CLK_IN  = 25000000,
    parameter CLK_OUT =  3571428
) (
    input  iClk,
    output oClkEn
);

`define NEW_CLK_GEN
`ifdef NEW_CLK_GEN

  reg [25:0] accum;
  reg en;
  assign oClkEn = en;

  always @(posedge iClk) begin
    if (accum > CLK_IN) begin
      accum <= accum - (CLK_IN - CLK_OUT);
      en <= 1;
    end else begin
      accum <= accum + CLK_OUT;
      en <= 0;
    end
  end

`else

  localparam ACCUM = (512 * CLK_OUT) / CLK_IN;

  reg [8:0] cnt0 = 0;
  wire [8:0] cnt1 = cnt0 + ACCUM;

  wire oClkEn = (cnt1[8] == 0) && (cnt0[8] == 1);

  always @(posedge iClk) begin
    cnt0 <= cnt1;
  end

`endif

endmodule
