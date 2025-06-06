`default_nettype none


//


module sdram(

  input         iClkCpu,
  input         iClkSdram,
  input         iRst,

  //
  // cpu interface
  //

  input  []
  input  [15:0] iWrData,
  output [15:0] oRdData,
  input  [ 1:0] iWr,
  input         iRd,
  input         oWrRdy,
  output        oRdRdy,

  //
  // sdram interface
  //

  input      [15:0] iSdramDq,           // data in
  output reg        oSdramClk   = 0,
  output reg        oSdramCke   = 0,
  output reg        oSdramCs    = 0,
  output reg        oSdramRas   = 0,
  output reg        oSdramCas   = 0,
  output reg        oSdramWe    = 0,
  output reg [12:0] oSdramA     = 0,
  output reg [ 1:0] oSdramBa    = 0,
  output reg [15:0] oSdramDq    = 0,    // data out
  output reg        oSdramDqEn  = 0,    // data out enable
  output reg [ 1:0] oSdramDqm   = 0     // byte select
);

  reg  [ 3:0] state;
  reg  [15:0] delay;

  reg  [15:0] refresh;

  reg  sdramSync = 0;
  reg  cpuSync   = 0;

  always @(posedge iClkSdram) begin

    // decrement delay count
    delay   <= delay   - |delay;
    // decrement refresh count
    refresh <= refresh - |refresh;

    // nops by default
    cmd <= CMD_NOP;

    if (delay == 0) begin

        // increment by default
        state <= state + 4'd1;
        // DQ input by default
        oSdramDqEn <= 0;

        case (state) begin

        //
        // reset
        //

        4'd0: begin
            // issue nops for 200us
            delay <= wait_200us;
            // reset trigger
            sdramSync <= 0;
        end
        4'd1: begin
            // issue precharge (all banks)
            cmd   <= CMD_PRECHARGE;
            delay <= wait_tRP;
        end
        4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9: begin
            // eight auto refresh cycles
            cmd   <= CMD_AUTO_REFRESH;
            delay <= wait_tRC;
        end
        4'd3: begin
            // load mode register
            cmd   <= CMD_MODE_SEL;
            { oSdramBa, oSdramA } <= {
                5'd0,       // reserved
                1'b1,       // single location access
                2'b00,      //
                3'b010,     // CAS latency 2
                1'b0,       // sequential access
                3'b000,     // burst length 1
            };
            delay <= wait_tMRD;
        end

        //
        // idle state
        //

        4'd4: begin
            // say in idle state
            state <= 4'd4;
            // issue auto refresh if needed
            if (refresh == 0) begin
              cmd     <= CMD_AUTO_REFRESH;
              delay   <= wait_tRC;
              refresh <= wait_refresh;
            end else begin
              if (cpuSync != sdramSync) begin
                  if ((iWr != 0) | (iRd != 0)) begin
                    cmd      <= CMD_ACTIVATE;
                    oSdramA  <= // ROW
                    oSdramBa <= // BANK
                    delay    <= wait_tRCD;
                  end
              end
            end
        end

        //
        // read / write
        //

        4'd5: begin

            { oSdramA[12:0] <= { 4'b1111, /*COLUMN*/ };
            // set byte enables
            oSdramDqm <= 2'b00;  // active low?

            if (iRd) begin
                cmd        <= CMD_READ;
                delay      <= wait_CAS;
                // goto read handler
                state      <= 4'd6;
            end
            if (iWr) begin
                cmd        <= CMD_WRITE;
                delay      <= tDPL + tRP;
                // goto to idle state
                state      <= 4'd4;
                // present data
                oSdramDqEn <= 1'b1;
                oSdramDq   <= /*data to write*/
                // trigger cpu side
                sdramSync  <= !sdramSync;
            end
        end

        //
        // read
        //

        4'd6: begin
            delay <= 1;  // (wait_tRP + 1) - wait_CAS
            // read in data from SDRAM
        end
        4'd7: begin
            state <= 4'd4;  // IDLE state
            // trigger cpu side
            sdramSync <= !sdramSync;
        end
        endcase
    end

    if (iRst) begin
      state <= 0;
    end
  end

endmodule
