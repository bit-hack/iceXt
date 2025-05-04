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
    input ps2_kdat
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
  // port hack
  //
  // the bios scroll routine tries to wait for vertical retrace by accessing
  // the CGA status register 0x3DA.
  // the routine reads the wrong bit when checking for vertical retrace.

  reg       ph_sel = 0;
  reg [7:0] ph_out = 0;

  always @(posedge pll_clk10) begin
    ph_sel <= 0;
    ph_out <= 8'hff;
    if (cpu_io_rd && cpu_addr[11:0] == 12'h3da) begin
      ph_sel <= 1;
    end
  end

  //
  // internal CPU bus
  //

  wire [ 7:0] cpu_data_in = bios_sel ? bios_out :
                             pic_sel ?  pic_out :
                              ph_sel ?   ph_out :
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
    .iIrq0  (irq0),             // timer
    .iIrq1  (0),             // keyboard
    .iIntAck(cpu_int_ack),   // cpu->pic int ack
    .oInt   (ex_cpu_intr),   // cpu<-pic int req
    .oSel   (pic_sel),
    .oData  (pic_out)
  );

  //
  // PIT timer
  //

  wire irq0;

  pit u_pit(
    .iClk (pll_clk10),
    .iRst (rst),
    .oIrq0(irq0) // ~18.2065hz
  );

  //
  // keyboard
  //

  wire       irq1;
  wire [7:0] keyboard_out;
  wire       keyboard_sel;

  ps2_keyboard u_ps2_keyboard(
      /*input        */.iClk   (pll_clk10),
      /*input [19:0] */.iAddr  (cpu_addr),
      /*input        */.iRd    (cpu_io_rd),
      /*output       */.oSel   (keyboard_sel),
      /*output [7:0] */.oData  (keyboard_out),
      /*output       */.oIrq   (irq1),
      /*input        */.iPs2Clk(ps2_mclk),
      /*input        */.iPs2Dat(ps2_mdat)
  );

  //
  // PMOD
  //
  assign pmod = {
    /*6*/1'b0,
    /*4*/1'b0,
    /*2*/ps2_kclk,
    /*0*/ps2_mclk,
    /*7*/1'b0,
    /*5*/1'b0,
    /*3*/ps2_kdat,
    /*1*/ps2_mdat
  };

endmodule
