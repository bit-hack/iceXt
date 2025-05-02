`default_nettype none

module sram_ctrl(
    input iClk,
    input iRd,
    input iWr,

    // external SRAM interface
    output oDir,  // 1(fpga->sram) 0(fpga<-sram)
    output oCe1,  // active low
    output oCe2,  // active high
    output oOe,   // active low
    output oWe    // active low
);

  reg dir = 0;  // 1(fpga->sram) 0(fpga<-sram)
  reg oe  = 1;  // active low
  reg we  = 1;  // active low
  reg dly = 0;

  always @(posedge iClk) begin
    if (dly == 0) begin
      oe  <= 1;
      we  <= 1;
      dir <= 0;
      if (iRd) begin
        we  <= 1;
        oe  <= 0;  // output enabled
        dir <= 0;  // fpga<-sram
        dly <= 1;
      end
      if (iWr) begin
        we  <= 0;  // write enable
        oe  <= 1;
        dir <= 1;  // fpga->sram
        dly <= 1;
      end
    end else begin
      dly <= 0;
    end
  end

  assign oDir = dir;
  assign oOe  = oe;
  assign oWe  = we;
  assign oCe1 = 0;
  assign oCe2 = 1;

endmodule
