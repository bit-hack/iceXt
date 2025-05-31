/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "../config.vh"


module ps2_device(
    input            iClk,

    input            iTx,
    input      [7:0] iTxData,
    output reg       oTxOk   = 0,
    output reg       oTxFail = 0,

    input            iInhibit,
    output           oIdle,

    output reg       oRx     = 0,
    output reg [7:0] oRxData = 0,

    input            iPs2Clk,
    input            iPs2Dat,
    output reg       oPs2Clk = 0,
    output reg       oPs2Dat = 0
);

  //
  // synchronizers
  //

  reg [ 3:0] sync_clk = 0;
  reg [ 3:0] sync_dat = 0;
  wire       clk_negedge = sync_clk[3] & (!sync_clk[2]);
  wire       data        = sync_dat[3];

  //
  // shift registers
  //

  reg [10:0] shift_in  = 0;
  reg [ 8:0] shift_out = 0;

  //
  // state machine
  //

  wire [15:0] DELAY_142us = 142 * (`CLOCK_SPEED / 1000000);  // 3550
  wire [15:0] DELAY_287us = 287 * (`CLOCK_SPEED / 1000000);  // 7175

  localparam STATE_IDLE    = 4'd0;
  localparam STATE_RX      = 4'd1;
  localparam STATE_RX_OK   = 4'd2;
  localparam STATE_TX      = 4'd3;
  localparam STATE_TX_OK   = 4'd4;
  localparam STATE_TX_FAIL = 4'd5;

  reg [ 3:0] state = 0;
  reg [ 7:0] count = 0;
  reg [15:0] delay = 0;

  assign oIdle = (state == STATE_IDLE);

  //
  // watchdog timeout
  //

  reg [13:0] timeout = 0;

  always @(posedge iClk) begin

    // deassert strobes
    oTxOk   <= 1'b0;
    oTxFail <= 1'b0;
    oRx     <= 1'b0;

    // synchronizers
    sync_clk <= { sync_clk[2:0], iPs2Clk };
    sync_dat <= { sync_dat[2:0], iPs2Dat };

    // delay counter
    delay <= (|delay) ? (delay - 16'd1) : 16'd0;

    // watchdog timeout
    timeout <= timeout + 1;
    if (clk_negedge) begin
      timeout <= 0;                 // activity, so reset timeout
    end
    if (timeout == 14'h3fff) begin
      state <= STATE_IDLE;          // timeout, force back to idle state
    end

    case (state)

    STATE_IDLE: begin

      oPs2Clk <= !iInhibit;  // release data (or inhibit)
      oPs2Dat <= 1;          // release clock

      // transmit begin
      if ((!iInhibit) & iTx) begin
        state     <= STATE_TX;
        shift_out <= { ~^iTxData, iTxData };
        count     <= 0;
      end

      // receive begin
      if ((!iInhibit) & clk_negedge & !data) begin
        state     <= STATE_RX;
        count     <= 0;
      end
    end

    STATE_TX: begin
      case (count)
      0: { count, oPs2Clk, delay } <= { 8'd1, 1'b0, DELAY_142us };  // pull clock low
      1: { count                 } <= (|delay) ? 8'd1: 8'd2;
      2: { count, oPs2Dat, delay } <= { 8'd3, 1'b0, DELAY_287us };  // pull data low
      3: { count                 } <= (|delay) ? 8'd3: 8'd4;
      4: { count, oPs2Clk        } <= { 8'd5, 1'b1              };  // release clock
      5, 6, 7, 8, 9, 10, 11, 12, 13: begin
        // shift out data and parity
        if (clk_negedge) begin
          oPs2Dat   <= shift_out[0];
          shift_out <= { 1'b1, shift_out[8:1] };
          count     <= count + 1;
        end
      end
      14: begin
        // shift out stop bit
        if (clk_negedge) begin
          count   <= 8'd15;
          oPs2Dat <= 1'b1;
        end
      end
      15: begin
        // check ACK response
        if (clk_negedge) begin
          state <= (!data) ? STATE_TX_OK : STATE_TX_FAIL;
        end
      end
      endcase
    end

    STATE_TX_OK: begin
        state <= STATE_IDLE;
        oTxOk <= 1'b1;
    end

    STATE_TX_FAIL: begin
        state   <= STATE_IDLE;
        oTxFail <= 1'b1;
    end

    STATE_RX: begin
      if (clk_negedge) begin
        shift_in <= { data, shift_in[10:1] };
        count    <= count + 1;
        if (count == 9) begin
          state <= STATE_RX_OK;
        end
      end
    end

    STATE_RX_OK: begin
      state   <= STATE_IDLE;
      // todo: check parity and stop bit
      oRxData <= shift_in[8:1];
      oRx     <= 1'b1;
    end

    default:
      state <= STATE_IDLE;
    endcase

  end

endmodule
