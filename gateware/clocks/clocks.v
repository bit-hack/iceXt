/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module pitClock #(
    parameter CLK_IN = 10000000
)
(
    input      iClk,
    output reg oClkEnPit    // 1.193182Mhz
);

  localparam ACCUM = (1193182 * 1024) / CLK_IN;

  reg  [9:0] count = 0;
  wire [9:0] next = count + ACCUM;

  always @(posedge iClk) begin
    oClkEnPit <= (next[9] ^ count[9]) & next[9];
    count <= next;
  end

endmodule
