`default_nettype none


module sdram(
  input         iClkCpu,
  input         iClkSdram,
  input         iRst,

  //
  // cpu interface
  //

  input  [23:0] iAddr,
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

  // banks| 4         bits| 2
  // row  | 8192      bits| 13
  // col  | 512       bits| 9
  wire bank   = iAddr[23:22];
  wire row    = iAddr[21: 9];
  wire column = iAddr[ 8: 0];

  //                         /RAS /CAS /WE
  localparam CMD_NOP       = 3'b1_1_1;
  localparam CMD_READ      = 3'b1_0_1;
  localparam CMD_WRITE     = 3'b1_0_0;
  localparam CMD_PRECHARGE = 3'b0_1_0;
  localparam CMD_ACTIVATE  = 3'b0_1_1;
  localparam CMD_REFRESH   = 3'b0_0_1;
  localparam CMD_MODE_SEL  = 3'b0_0_0;


  // at 1mhz, the period is exactly 1us

  localparam wait_200us   = ;
  localparam wait_CAS     = 2;
  localparam wait_refresh = ;
  localparam wait_tMRD    = ;
  localparam wait_tRC     = ;
  localparam wait_tRCD    = ;
  localparam wait_tRP     = ;

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

        case (state)

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
            // issue pre-charge
            cmd         <= CMD_PRECHARGE;
            oSdramA[10] <= 1'b1;  // all banks
            delay       <= wait_tRP;
        end
        4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9: begin
            // eight auto refresh cycles
            cmd   <= CMD_REFRESH;
            delay <= wait_tRC;
        end
        4'd3: begin
            // load mode register
            cmd <= CMD_MODE_SEL;
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
              cmd     <= CMD_REFRESH;
              delay   <= wait_tRC;
              refresh <= wait_refresh;
            end else begin
              if (cpuSync != sdramSync) begin
                  if ((iWr != 0) | (iRd != 0)) begin
                    cmd      <= CMD_ACTIVATE;
                    oSdramA  <= row;  // 13 bits
                    oSdramBa <= bank; // 2 bits
                    delay    <= wait_tRCD;
                  end
              end
            end
        end

        //
        // read / write
        //

        4'd5: begin

            oSdramA[12:0] <= {
              4'b1111,
              column    // 9 bits
            };

            if (iRd) begin
                cmd        <= CMD_READ;
                delay      <= wait_CAS;
                oSdramDqm  <= 2'b00;
                // goto read handler
                state      <= 4'd6;
            end
            if (iWr) begin
                cmd        <= CMD_WRITE;
                delay      <= tDPL + tRP;
                // goto to idle state
                state      <= 4'd4;
                // byte select (active low)
                oSdramDqm  <= ~iWr;
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
            oRdData <= iSdramDq;
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
