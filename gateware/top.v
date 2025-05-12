/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/
`default_nettype none

`include "config.vh"


module top(
    input         clk25,
    input         sw_rst,

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
    output        vga_hs,

    // pmod
    output [ 7:0] pmod,

    // PS/2 interface
    input ps2_mclk,
    input ps2_mdat,
    input ps2_kclk,
    input ps2_kdat,

    // SD card
    input  sd_do,
    output sd_di,
    output sd_clk,
    output sd_cs,

    // misc
    output led_io,
    output pit_spk
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
  // BIOS ROM
  //

  wire [7:0] bios_rom_out;
  wire       bios_rom_sel;
  biosRom u_biosrom(
    .iClk (pll_clk10),
    .iAddr(cpu_addr),
    .iRd  (cpu_mem_rd),
    .oSel (bios_rom_sel),
    .oData(bios_rom_out)
  );

  //
  // disk ROM
  //

  wire [7:0] disk_rom_out;
  wire       disk_rom_sel;
  diskRom u_diskrom(
    .iClk (pll_clk10),
    .iAddr(cpu_addr),
    .iRd  (cpu_mem_rd),
    .oSel (disk_rom_sel),
    .oData(disk_rom_out)
  );

  //
  // internal CPU bus
  //

  wire [ 7:0] cpu_data_in =
      bios_rom_sel ? bios_rom_out :
      disk_rom_sel ? disk_rom_out :
           pic_sel ?      pic_out :
            sd_sel ?       sd_out :
      keyboard_sel ? keyboard_out :
           pit_sel ? pit_data_out :
                           sram_d;
  wire [ 7:0] cpu_data_out;
  wire        cpu_mem_rd;
  wire        cpu_mem_wr;
  wire        cpu_io_rd;
  wire        cpu_io_wr;
  wire        cpu_int_ack;
  wire [19:0] cpu_addr;

  //
  // internal to external CPU bus bridge
  //

  cpu_bus u_cpu_bus(
    .iClk      (pll_clk10),

    // internal cpu interface
    .iCpuRst   (rst),
    .iCpuData  (cpu_data_in),
    .oCpuData  (cpu_data_out),
    .oCpuAddr  (cpu_addr),
    .oCpuMemRd (cpu_mem_rd),
    .oCpuMemWr (cpu_mem_wr),
    .oCpuIoRd  (cpu_io_rd),
    .oCpuIoWr  (cpu_io_wr),
    .oCpuIntAck(cpu_int_ack),

    // external NEC V20 interface
    .iV20Ale   (ex_cpu_ale),
    .iV20Sso   (ex_cpu_sso),
    .iV20Dtr   (ex_cpu_dtr),      // 1-wr, 0-rd
    .iV20Iom   (ex_cpu_iom),      // 1-io, 0-mem
    .iV20Data  (ex_cpu_ad),       // data / low addr 8bits
    .iV20Addr  (ex_cpu_ah),       // upper addr 12bits
    .oV20Data  (ex_cpu_data_out),
    .oV20Clk   (ex_cpu_clk),      // iClk/2
    .oV20Dir   (ex_cpu_data_dir), // 1(fpga->v20), 0(v20->fpga)
    .oV20Reset (ex_cpu_reset)
  );

  //
  // external CPU bus
  //

  wire       ex_cpu_data_dir;
  wire [7:0] ex_cpu_data_out;

  assign ex_cpu_test  = 1;
  assign ex_cpu_ready = 1;
  assign ex_cpu_nmi   = 0;
  assign ex_cpu_hold  = 0;
  assign ex_cpu_mn    = 1;
  assign ex_cpu_ad    = ex_cpu_data_dir ? ex_cpu_data_out : 8'bzzzzzzzz;

  //
  // VGA interface
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
  // SRAM interface
  //

  wire sram_dir;

  sram_ctrl u_sram_ctrl(
    .iClk(pll_clk10),
    .iRd (cpu_mem_rd),
    .iWr (cpu_mem_wr),
    .oDir(sram_dir),  // 1(fpga->sram) 0(fpga<-sram)
    .oCe1(sram_ce1),
    .oCe2(sram_ce2),
    .oOe (sram_oe),
    .oWe (sram_we)
  );

  assign sram_a = cpu_addr;
  assign sram_d = sram_dir ? cpu_data_out : 8'bzzzzzzzz;

  //
  // PIC interrupt controller
  //

  wire       pic_sel;
  wire [7:0] pic_out;

  pic u_pic(
    .iClk   (pll_clk10),
    .iRst   (rst),
    .iIrq0  (irq0),          // timer
    .iIrq1  (irq1),          // keyboard
    .iIntAck(cpu_int_ack),   // cpu->pic int ack
    .oInt   (ex_cpu_intr),   // cpu<-pic int req
    .oSel   (pic_sel),
    .oData  (pic_out)
  );

  //
  // PIT timer
  //


  wire pitClkEn;
  pitClock u_pit_clock(
    .iClk     (pll_clk10),
    .oClkEnPit(pitClkEn)  // 1.193182Mhz
  );

  wire       irq0;
  wire       pit_channel_2;
  wire [7:0] pit_data_out;
  wire       pit_sel;
  pit2 u_pit(
    .iClk  (pll_clk10),
    .iClkEn(pitClkEn),  // 1.193182Mhz
    .iData (cpu_data_out),
    .iAddr (cpu_addr),
    .iWr   (cpu_io_wr),
    .iRd   (cpu_io_rd),
    .iGate2(spk_gate),  // pit spk enable
    .oOut0 (irq0),
    .oOut2 (pit_channel_2),
    .oData (pit_data_out),
    .oSel  (pit_sel)
  );

  assign pit_spk = (pit_channel_2 & spk_enable) ^ sd_click;

  //
  // keyboard
  //

  wire       irq1;
  wire [7:0] keyboard_out;
  wire       keyboard_sel;
  wire       spk_gate;
  wire       spk_enable;

  ps2_keyboard u_ps2_keyboard(
      .iClk      (pll_clk10),
      .iAddr     (cpu_addr),
      .iRd       (cpu_io_rd),
      .iWr       (cpu_io_wr),
      .iData     (cpu_data_out),
      .oSel      (keyboard_sel),
      .oData     (keyboard_out),
      .oIrq      (irq1),
      .oSpkGate  (spk_gate),
      .oSpkEnable(spk_enable),
      .iPs2Clk   (ps2_mclk),
      .iPs2Dat   (ps2_mdat)
  );

  //
  // SD Card
  //

  wire [7:0] sd_out;
  wire       sd_sel;
  wire       sd_click;
  sdCard u_sdcard(
    .iClk   (pll_clk10),
    .iAddr  (cpu_addr),
    .iWr    (cpu_io_wr),
    .iRd    (cpu_io_rd),
    .iData  (cpu_data_out),
    .oData  (sd_out),
    .oSel   (sd_sel),
    .iSdMiso(sd_do),
    .oSdMosi(sd_di),
    .oSdSck (sd_clk),
    .oSdCs  (sd_cs),
    .oBusy  (led_io),
    .oClick (sd_click)
  );

  //
  // PMOD
  //
  assign pmod = {
    /*6*/1'b0,
    /*4*/spk_enable,
    /*2*/pit_channel_2,
    /*0*/pitClkEn,
    /*7*/1'b0,
    /*5*/1'b0,
    /*3*/spk_gate,
    /*1*/irq0
  };

endmodule
