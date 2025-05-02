`default_nettype none

`include "config.vh"


module top(
    input         clk25,
    input         sw_rst,
    output [ 7:0] pmod,

    // external cpu interface
    input  [11:0] ex_cpu_ah,
    inout  [ 7:0] ex_cpu_ad,
    input         ex_cpu_sso,
    input         ex_cpu_iom,
    input         ex_cpu_dtr,
    input         ex_cpu_ale,
    output        ex_cpu_clk,
    output        ex_cpu_reset,
    output        ex_cpu_nmi,
    output        ex_cpu_intr,
    output        ex_cpu_test,
    output        ex_cpu_ready,
    output        ex_cpu_hold,
    output        ex_cpu_mn,

    // external sram interface
    output [19:0] sram_a,
    inout  [ 7:0] sram_d,
    output        sram_ce1,  // active low
    output        sram_ce2,  // active high
    output        sram_oe,   // active low
    output        sram_we,   // active low

    // vga interface
    output [ 3:0] vga_r,
    output [ 3:0] vga_g,
    output [ 3:0] vga_b,
    output        vga_vs,
    output        vga_hs
);

  //
  // clock pll
  //

  wire pll_clk10;
  wire pll_clk25;
  wire pll_locked;
  pll u_pll(
    .clkin  (clk25),     // 25 MHz
    .clkout0(pll_clk10), // 10 MHz
    .clkout1(pll_clk25), // 25 MHz
    .locked (pll_locked)
  );

  //
  // reset generator
  //

  wire rst;
  reset u_reset (
    .iClk  (pll_clk10),
    .iReset(~sw_rst | ~pll_locked),
    .oReset(rst)
  );

  //
  // BIOS
  //

  wire       bios_sel;
  wire [7:0] bios_out;
  bios u_bios(
    .iClk (pll_clk10),
    .iAddr(cpu_addr),
    .iRd  (cpu_mem_rd),
    .oSel (bios_sel),
    .oData(bios_out)
  );

  //
  // internal cpu bus
  //

  wire [ 7:0] cpu_data_in = bios_sel ? bios_out :
                                       sram_d;
  wire [ 7:0] cpu_data_out;
  wire        cpu_mem_rd;
  wire        cpu_mem_wr;
  wire        cpu_io_rd;
  wire        cpu_io_wr;
  wire [19:0] cpu_addr;

  //
  // internal to external cpu bus bridge
  //

  cpu_bus u_cpu_bus(
    .iClk     (pll_clk10),

    // internal cpu interface
    .iCpuRst  (rst),
    .iCpuData (cpu_data_in),
    .oCpuData (cpu_data_out),
    .oCpuAddr (cpu_addr),
    .oCpuMemRd(cpu_mem_rd),
    .oCpuMemWr(cpu_mem_wr),
    .oCpuIoRd (cpu_io_rd),
    .oCpuIoWr (cpu_io_wr),

    // external NEC V20 interface
    .iV20Ale  (ex_cpu_ale),
    .iV20Sso  (ex_cpu_sso),
    .iV20Dtr  (ex_cpu_dtr),      // 1-wr, 0-rd
    .iV20Iom  (ex_cpu_iom),      // 1-io, 0-mem
    .iV20Data (ex_cpu_ad),       // data / low addr 8bits
    .iV20Addr (ex_cpu_ah),       // upper addr 12bits
    .oV20Data (ex_cpu_data_out),
    .oV20Clk  (ex_cpu_clk),      // 5Mhz
    .oV20Dir  (ex_cpu_data_dir), // 1(fpga->v20), 0(v20->fpga)
    .oV20Reset(ex_cpu_reset)
  );

  //
  // external cpu bus
  //

  wire       ex_cpu_data_dir;
  wire [7:0] ex_cpu_data_out;

  assign ex_cpu_test  = 1;
  assign ex_cpu_ready = 1;
  assign ex_cpu_nmi   = 0;
  assign ex_cpu_intr  = 0;
  assign ex_cpu_hold  = 0;
  assign ex_cpu_mn    = 1;
  assign ex_cpu_ad    = ex_cpu_data_dir ? ex_cpu_data_out : 8'bzzzzzzzz;

  //
  // vga interface
  //
  video_mda u_video_mda(
    .iClk  (pll_clk10),
    .iClk25(pll_clk25),
    .iAddr (cpu_addr),
    .iData (cpu_data_out),
    .iWr   (cpu_mem_wr),
    .oVgaR (vga_r),
    .oVgaG (vga_g),
    .oVgaB (vga_b),
    .oVgaHs(vga_hs),
    .oVgaVs(vga_vs)
  );

  //
  // sram interface
  //

  reg sram_dir = 0;  // 1(fpga->sram) 0(fpga<-sram)
  reg sram_oe  = 1;  // active low
  reg sram_we  = 1;  // active low
  reg sram_dly = 0;

  always @(posedge pll_clk10) begin
    if (sram_dly == 0) begin
      sram_oe  <= 1;
      sram_we  <= 1;
      sram_dir <= 0;
      if (cpu_mem_rd) begin
        sram_we  <= 1;
        sram_oe  <= 0;  // output enabled
        sram_dir <= 0;  // fpga<-sram
        sram_dly <= 1;
      end
      if (cpu_mem_wr) begin
        sram_we  <= 0;  // write enable
        sram_oe  <= 1;
        sram_dir <= 1;  // fpga->sram
        sram_dly <= 1;
      end
    end else begin
      sram_dly <= 0;
    end
  end

  assign sram_a   = cpu_addr;
  assign sram_d   = sram_dir ? cpu_data_out : 8'bzzzzzzzz;
  assign sram_ce1 = 0;  // active low
  assign sram_ce2 = 1;  // active high

endmodule
