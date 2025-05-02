/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module clkEnGen #(
    parameter CLK_IN  = 25000000,
    parameter CLK_OUT =  3571428
) (
    input  iClk,
    output oClkEn
);

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
endmodule
