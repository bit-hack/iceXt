/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


// Uart waveform:
//
//       lsb ------- msb
//     S 0 1 2 3 4 5 6 7 S
//     | | | | | | | | | |
//  --. .-.   .-. .-.   .---
//    |_| |___| |_| |___|
//

module uartRx(
  input        iClk,
  input        iRx,
  output [7:0] oData,
  output reg   oValid,
  output       oBusy
);

  parameter CLK_FREQ     = 10000000;
  parameter BAUD         =   115200;
  parameter CLK_DIV      = CLK_FREQ / BAUD;
  parameter CLK_DIV_HALF = CLK_DIV / 2;

  reg [ 3:0] rxp;
  reg [ 3:0] state;
  reg [11:0] div;
  reg [ 8:0] shift;

  assign oData = shift[7:0];
  assign oBusy = state != 0;

  always @(posedge iClk) begin
    rxp    <= { rxp[2:0], iRx };
    oValid <= 0;

    case (state)
    0:
      // starting edge
      if (rxp[3]==1 & rxp[2]==0) begin
        div   <= CLK_DIV_HALF;
        state <= 1;
      end
    11: begin
        oValid <= shift[8];  // valid stop bit
        state  <= 0;
      end
    default:
      if (div == 0) begin
        state <= state + 1;
        div   <= CLK_DIV;
        shift <= { rxp[3], shift[8:1] };
      end else begin
        div <= div - 1;
      end
    endcase
  end
endmodule
