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

    // vga interface
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output       vga_vs,
    output       vga_hs
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
  // dummy RAM
  //

  reg [7:0] ram[8192];
  reg [7:0] ram_out;

  initial $readmemh("program.hex", ram);

  always @(posedge pll_clk10) begin
    if (cpu_mem_wr) begin
      ram[ cpu_addr[12:0] ] <= cpu_data_out;
    end
    if (cpu_mem_rd) begin
      ram_out <= ram[ cpu_addr[12:0] ];
    end
  end

  //
  // port latch
  //

  reg [7:0] port;

  always @(posedge pll_clk10) begin
    if (cpu_io_wr) begin
      if (cpu_addr[7:0] == 8'h2a) begin
        port <= cpu_data_out;
      end
    end
  end

  //
  // internal cpu bus
  //

  wire [ 7:0] cpu_data_in = ram_out;
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
  // pmod connector
  //

  assign pmod = {
    /*6*/port[6],
    /*4*/port[4],
    /*2*/port[2],
    /*0*/port[0],
    /*7*/port[7],
    /*5*/port[5],
    /*3*/port[3],
    /*1*/port[1]
  };

  //
  // address decoder
  //

  // [00000 ... 9ffff]
  wire selRam = cpu_addr[19] == 0 |
                cpu_addr[19:17] == 3'b100;

  // [B0000 ... B7fff]
  wire selVram = cpu_addr[19:15] == 5'b10110;

  // [FE000 ... FFFFF]
  wire selBios = cpu_addr[19:13] == 7'b1111111;

  //
  // vga interface
  //
  video_mda u_video_mda(
    /*input        */.iClk  (pll_clk10),
    /*input        */.iClk25(pll_clk25),
    /*input [19:0] */.iAddr (cpu_addr),
    /*input [ 7:0] */.iData (cpu_data_out),
    /*input        */.iWr   (cpu_mem_wr & selVram),
    /*output [3:0] */.oVgaR (vga_r),
    /*output [3:0] */.oVgaG (vga_g),
    /*output [3:0] */.oVgaB (vga_b),
    /*output       */.oVgaHs(vga_hs),
    /*output       */.oVgaVs(vga_vs)
  );

endmodule
