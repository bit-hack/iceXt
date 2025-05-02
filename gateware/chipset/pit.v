/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


module pit(
  input        iClk,        // 10Mhz
  input        iRst,
  output       oIrq0        // ~18.2065hz
);

  reg [19:0] count   = 0;
  reg        trigger = 0;

  always @(posedge iClk) begin
    trigger <= 0;
    if (count == 0) begin
      count <= 19'd549254;
      trigger <= 1;
    end else begin
      count <= count - 1;
    end
  end

  assign oIrq0 = trigger;

endmodule
