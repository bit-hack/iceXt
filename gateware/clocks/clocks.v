/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module pitClock(
    input      iClk,        // 10Mhz
    output reg oClkEnPit    // 1.193182Mhz
);

  reg  [9:0] count = 0;
//  wire [9:0] next = count + 10'd122;
  wire [9:0] next = count + 10'd73;

  always @(posedge iClk) begin
    oClkEnPit <= (next[9] ^ count[9]) & next[9];
    count <= next;
  end

endmodule
