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
    input clk25,
    input sw_rst,

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

    // PS/2 interface
    inout ps2_mclk,
    inout ps2_mdat,
    inout ps2_kclk,
    inout ps2_kdat,

    // SD card
    input  sd_do,
    output sd_di,
    output sd_clk,
    output sd_cs,

    // ym3014 DAC
    output ym_sd,
    output ym_load,
    output ym_clk,

    // misc
    output led_io,
    output pit_spk,

    // FPGA serial
    output serial_tx,
    input  serial_rx,

    // pmod
    output [7:0] pmod
);

  //
  // clock pll
  //

  wire pll_clk_bus;
  wire pll_clk_25;
  wire pll_locked;

  pll u_pll(
    .clkin  (clk25),
    .clkout0(pll_clk_bus),
    .clkout1(pll_clk_25),
    .locked (pll_locked)
  );

  //
  // reset generator
  //

  wire rst;

  reset u_reset (
    .iClk  (pll_clk_bus),
    .iReset(~sw_rst | ~pll_locked),
    .oReset(rst)
  );

  //
  // BIOS ROM
  //

  wire [7:0] bios_rom_out;
  wire       bios_rom_sel;

  biosRom u_biosrom(
    .iClk (pll_clk_bus),
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
    .iClk (pll_clk_bus),
    .iAddr(cpu_addr),
    .iRd  (cpu_mem_rd),
    .oSel (disk_rom_sel),
    .oData(disk_rom_out)
  );

  //
  // internal CPU bus
  //

  reg port_sel = 0;
  always @(posedge pll_clk_bus) begin
    if (cpu_io_rd)  port_sel <= 1;
    if (cpu_mem_rd) port_sel <= 0;
  end

  wire [ 7:0] cpu_data_in =
      bios_rom_sel ? bios_rom_out :
      disk_rom_sel ? disk_rom_out :
           pic_sel ?      pic_out :
            sd_sel ?       sd_out :
          com1_sel ?     com1_out :
          com2_sel ?     com2_out :
      keyboard_sel ? keyboard_out :
           pit_sel ? pit_data_out :
           cga_sel ?      cga_out :
           ega_sel ?      ega_out :
//          port_sel ?        8'hff :  // model unoccupied port space (causes display to not init?!)
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
    .iClk      (pll_clk_bus),

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
  // CGA interface
  //

  wire [7:0] cga_out;
  wire       cga_sel;
  wire [3:0] cga_r;
  wire [3:0] cga_g;
  wire [3:0] cga_b;
  wire       cga_hs;
  wire       cga_vs;

  video_cga u_video_cga(
    .iClk   (pll_clk_bus),
    .iClk25 (pll_clk_25),
    .iAddr  (cpu_addr),
    .iWrData(cpu_data_out),
    .iWrMem (cpu_mem_wr),
    .iWrIo  (cpu_io_wr),
    .iRdIo  (cpu_io_rd),
    .oRdData(cga_out),
    .oSel   (cga_sel),
    .oVgaR  (cga_r),
    .oVgaG  (cga_g),
    .oVgaB  (cga_b),
    .oVgaHs (cga_hs),
    .oVgaVs (cga_vs)
  );
  
  //
  // EGA interface
  //

  wire [7:0] ega_out;
  wire       ega_sel;
  wire [3:0] ega_r;
  wire [3:0] ega_g;
  wire [3:0] ega_b;
  wire       ega_hs;
  wire       ega_vs;
  wire       ega_active;

  video_ega u_video_ega(
    .iClk   (pll_clk_bus),
    .iClk25 (pll_clk_25),
    .iAddr  (cpu_addr),
    .iWrData(cpu_data_out),
    .iWrMem (cpu_mem_wr),
    .iRdMem (cpu_mem_rd),
    .iWrIo  (cpu_io_wr),
    .iRdIo  (cpu_io_rd),
    .oRdData(ega_out),
    .oSel   (ega_sel),
    .oVgaR  (ega_r),
    .oVgaG  (ega_g),
    .oVgaB  (ega_b),
    .oVgaHs (ega_hs),
    .oVgaVs (ega_vs),
    .oActive(ega_active)
  );

  //
  // multiplex into the VGA output
  //
  
  assign vga_r  = ega_active ? ega_r  : cga_r;
  assign vga_g  = ega_active ? ega_g  : cga_g;
  assign vga_b  = ega_active ? ega_b  : cga_b;
  assign vga_vs = ega_active ? ega_vs : cga_vs;
  assign vga_hs = ega_active ? ega_hs : cga_hs;

  //
  // SRAM interface
  //

  wire sram_dir;

  sram_ctrl u_sram_ctrl(
    .iClk(pll_clk_bus),
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
    .iClk   (pll_clk_bus),
    .iRst   (rst),
    .iIrq0  (irq0),          // timer
    .iIrq1  (irq1),          // keyboard
    .iIrq3  (com2_intr),     // com3
    .iIrq4  (com1_intr),     // com1
    .iIntAck(cpu_int_ack),   // cpu->pic int ack

    .iAddr  (cpu_addr),
    .iWrData(cpu_data_out),
    .iWr    (cpu_io_wr),
    .iRd    (cpu_io_rd),

    .oInt   (ex_cpu_intr),   // cpu<-pic int req
    .oSel   (pic_sel),
    .oData  (pic_out)
  );

  //
  // PIT timer
  //

  wire pitClkEn;

  pitClock #(.CLK_IN(`CLOCK_SPEED)) u_pit_clock(
    .iClk     (pll_clk_bus),
    .oClkEnPit(pitClkEn)  // 1.193182Mhz
  );

  wire       irq0;
  wire       pit_channel_2;
  wire [7:0] pit_data_out;
  wire       pit_sel;

  pit u_pit(
    .iClk  (pll_clk_bus),
    .iClkEn(pitClkEn),
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
  // keyboard controller
  //

  wire [7:0] keyboard_out;
  wire       keyboard_sel;

  wire       irq1;
  wire       spk_gate;
  wire       spk_enable;

  wire       ps2_mclk_od;
  wire       ps2_mdat_od;
  assign     ps2_mclk = ps2_mclk_od ? 1'bz : 1'b0;
  assign     ps2_mdat = ps2_mdat_od ? 1'bz : 1'b0;

  keyboard_ctrl u_keyboard_ctrl(
    .iClk      (pll_clk_bus),
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
    .iPs2Dat   (ps2_mdat),
    .oPs2Clk   (ps2_mclk_od),
    .oPs2Dat   (ps2_mdat_od)
  );

  //
  // SD Card
  //

  wire [7:0] sd_out;
  wire       sd_sel;
  wire       sd_click;

  sdCard u_sdcard(
    .iClk   (pll_clk_bus),
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
  // adlib audio
  //

`ifdef CFG_ENABLE_ADLIB
  adlib u_adlib(
    .iClk   (pll_clk_bus),
    .iRst   (rst),
    .iWr    (cpu_io_wr),
    .iWrData(cpu_data_out),
    .iAddr  (cpu_addr),
    .oYmSd  (ym_sd),
    .oYmLoad(ym_load),
    .oYmClk (ym_clk)
  );
`endif

  //
  // COM1 UART -> PS/2 mouse bridge
  //

`ifdef CFG_ENABLE_COM1_MOUSE
  wire       ps2_kclk_od;
  wire       ps2_kdat_od;
  assign     ps2_kclk = ps2_kclk_od ? 1'bz : 1'b0;
  assign     ps2_kdat = ps2_kdat_od ? 1'bz : 1'b0;

  wire [7:0] com1_out;
  wire       com1_sel;
  wire       com1_intr;

  uartMouse #(.BASE(12'h3f8)) u_uart_mouse(
    .iClk    (pll_clk_bus),
    .iRst    (rst),
    .iAddr   (cpu_addr),
    .iWr     (cpu_io_wr),
    .iWrData (cpu_data_out),
    .iRd     (cpu_io_rd),
    .oRdData (com1_out),
    .oSel    (com1_sel),
    .oIntr   (com1_intr),
    .iPs2Clk (ps2_kclk),
    .iPs2Data(ps2_kdat),
    .oPs2Clk (ps2_kclk_od),
    .oPs2Data(ps2_kdat_od)
  );
`else
  wire [7:0] com1_out  = 8'h00;
  wire       com1_sel  = 1'b0;
  wire       com1_intr = 1'b0;
`endif

  //
  // COM2 UART -> PC bridge
  //

`ifdef CFG_ENABLE_COM2_BRIDGE
  wire [7:0] com2_out;
  wire       com2_sel;
  wire       com2_intr;

  uartBridge #(.BASE(12'h2f8)) u_uart_bridge(
    .iClk   (pll_clk_bus),
    .iAddr  (cpu_addr),
    .iWr    (cpu_io_wr),
    .iWrData(cpu_data_out),
    .iRd    (cpu_io_rd),
    .oRdData(com2_out),
    .oSel   (com2_sel),
    .oIntr  (com2_intr),
    .iRx    (serial_rx),
    .oTx    (serial_tx)
  );
`else
  wire [7:0] com2_out  = 8'h00;
  wire       com2_sel  = 1'b0;
  wire       com2_intr = 1'b0;
`endif

  //
  // PMOD
  //

  wire [7:0] debug = 8'h00;
  assign pmod = {
    /*6*/debug[6],
    /*4*/debug[4],
    /*2*/debug[2],
    /*0*/debug[0],
    /*7*/debug[7],
    /*5*/debug[5],
    /*3*/debug[3],
    /*1*/debug[1]
  };

endmodule
