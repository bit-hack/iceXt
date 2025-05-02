/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none


//                 8088
//             _____  _____
//      GND o-|1    \/   40|-o VCC
// <-   A14 o-|2         39|-o A15      ->
// <-   A13 o-|3         38|-o A16      ->
// <-   A12 o-|4         37|-o A17      ->
// <-   A11 o-|5         36|-o A18      ->
// <-   A10 o-|6         35|-o A19      ->
// <-    A9 o-|7         34|-o /SSO     ->
// <-    A8 o-|8         33|-o MN /MX  <-
// <->  AD7 o-|9         32|-o /RD      ->
// <->  AD6 o-|10        31|-o HOLD    <-
// <->  AD5 o-|11        30|-o HLDA     ->
// <->  AD4 o-|12        29|-o /WR      ->
// <->  AD3 o-|13        28|-o IO /M    ->
// <->  AD2 o-|14        27|-o DT /R    ->
// <->  AD1 o-|15        26|-o /DEN     ->
// <->  AD0 o-|16        25|-o ALE      ->
//  ->  NMI o-|17        24|-o /INTA    ->
//  -> INTR o-|18        23|-o /TEST   <-
//  ->  CLK o-|19        22|-o READY   <-
//      GND o-|20        21|-o RESET   <-
//            '------------'


module cpu_bus(
  input             iClk,

  // internal cpu interface

  input             iCpuRst,       // 1-reset
  input      [ 7:0] iCpuData,
  output reg [ 7:0] oCpuData   = 0,
  output reg [19:0] oCpuAddr   = 0,
  output reg        oCpuMemRd  = 0,
  output reg        oCpuMemWr  = 0,
  output reg        oCpuIoRd   = 0,
  output reg        oCpuIoWr   = 0,
  output reg        oCpuIntAck = 0,

  // external NEC V20 interface

  input             iV20Ale,
  input             iV20Sso,
  input             iV20Dtr,       // 1-wr, 0-rd
  input             iV20Iom,       // 1-io, 0-mem
  input      [ 7:0] iV20Data,      // data / low addr 8bits
  input      [11:0] iV20Addr,      // upper addr 12bits
  output reg [ 7:0] oV20Data = 0,
  output reg        oV20Clk  = 0,  // 1/2 iClk
  output reg        oV20Dir  = 0,  // 1(fpga->v20), 0(v20->fpga)
  output            oV20Reset
);

  localparam BUS_CYCLE_FETCH     = 3'b000;
  localparam BUS_CYCLE_MEM_READ  = 3'b001;
  localparam BUS_CYCLE_MEM_WRITE = 3'b010;
  localparam BUS_CYCLE_PASSIVE   = 3'b011;
  localparam BUS_CYCLE_INT_ACK   = 3'b100;
  localparam BUS_CYCLE_IO_READ   = 3'b101;
  localparam BUS_CYCLE_IO_WRITE  = 3'b110;
  localparam BUS_CYCLE_HALT      = 3'b111;

  reg  [2:0] state      = 0;
  wire [3:0] state_next = state + 4'd1;
  reg  [2:0] kind       = 0;

  reg [2:0] rstCnt = 3'h7;
  assign oV20Reset = |rstCnt;

  always @(posedge iClk) begin

    oV20Clk <= ~oV20Clk;

    rstCnt <= iCpuRst ? 3'h7 :
              (oV20Clk & |rstCnt) ? (rstCnt - 1) :
              rstCnt;

    oCpuMemRd  <= 0;
    oCpuMemWr  <= 0;
    oCpuIoRd   <= 0;
    oCpuIoWr   <= 0;
    oCpuIntAck <= 0;

    //       0  1  2  3  4  5  6  7     STATE
    //    |T1   |T2   |T3   |T4   |
    //  __    __    __    __    __   
    // |  |__|  |__|  |__|  |__|  |__   CLK
    //       v              v
    //      ___
    //  ___|   |_____________________   ALE
    //     _____       _________
    //  --<_____>-----<_________>----   AD[7:0]
    //     _____
    //  --<_____>--------------------   A[19:8]

    case (state)
    0: begin  // T1...(no-sync)
      oV20Dir    <= 0;
      if (iV20Ale && oV20Clk==0) begin
        state    <= state_next;
        // sample full address
        oCpuAddr <= { iV20Addr, iV20Data };
        // bus cycle kind
        kind     <= { iV20Iom, iV20Dtr, iV20Sso };
      end
    end
    1: begin  // T1.5 (high)
      oCpuMemRd  <= kind == BUS_CYCLE_FETCH |
                    kind == BUS_CYCLE_MEM_READ;
      oCpuIoRd   <= kind == BUS_CYCLE_IO_READ;
      oCpuIntAck <= kind == BUS_CYCLE_INT_ACK;
      state      <= state_next;
    end
    2: begin  // T2   (low)
      // this cycle lets iCpuData become ready
      state      <= state_next;
    end
    3: begin  // T2.5 (high)
      oV20Data   <= iCpuData;
      state      <= state_next;
    end
    4: begin  // T3   (low)
      oV20Dir    <= kind == BUS_CYCLE_FETCH    |
                    kind == BUS_CYCLE_MEM_READ |
                    kind == BUS_CYCLE_IO_READ  |
                    kind == BUS_CYCLE_INT_ACK;
      state      <= state_next;
    end
    5: begin  // T3.5 (high)
      oCpuData   <= iV20Data;
      oCpuMemWr  <= kind == BUS_CYCLE_MEM_WRITE;
      oCpuIoWr   <= kind == BUS_CYCLE_IO_WRITE;
      state      <= state_next;
    end
    6: begin  // T4   (low)
      oV20Dir    <= 0;
      state      <= state_next;
    end
    7: begin  // T4.5 (high)
      state      <= 0;
    end
    endcase
  end
endmodule
