`default_nettype none

`include "config.vh"


module top(
    input         clk25,
    input         sw_rst,
    output [ 7:0] pmod,
    input  [11:0] cpu_ah,
    inout  [ 7:0] cpu_ad,
    input         cpu_sso,
    input         cpu_iom,
    input         cpu_dtr,
    input         cpu_ale,
    output        cpu_clk,
    output        cpu_reset,
    output        cpu_nmi,
    output        cpu_intr,
    output        cpu_test,
    output        cpu_ready,
    output        cpu_hold,
    output        cpu_mn
    );

  wire pll_clk10;
  wire pll_clk25;
  wire pll_locked;
  pll u_pll(
    .clkin  (clk25),     // 25 MHz, 0 deg
    .clkout0(pll_clk10), // 10 MHz, 0 deg
    .clkout1(pll_clk25), // 25 MHz, 0 deg
    .locked (pll_locked)
  );

  wire rst;
  reset u_reset (
    .iClk  (pll_clk10),
    .iReset(~sw_rst | ~pll_locked),
    .oReset(rst)
  );

  wire       cpu_dir;
  wire [7:0] cpu_data_out;
  assign cpu_ad = cpu_dir ? cpu_data_out : 8'bzzzzzzzz;

  wire cpu_mem_rd;

  assign cpu_test  = 1;
  assign cpu_ready = 1;
  assign cpu_nmi   = 0;
  assign cpu_intr  = 0;
  assign cpu_hold  = 0;
  assign cpu_mn    = 1;

  cpu_bus u_cpu_bus(
    /*input            */.iClk(pll_clk10),

    // internal cpu interface

    /*input            */.iCpuRst  (rst),
    /*input      [ 7:0]*/.iCpuData (8'h90),
    /*output reg [ 7:0]*/.oCpuData (),
    /*output reg [19:0]*/.oCpuAddr (),
    /*output reg       */.oCpuMemRd(cpu_mem_rd),
    /*output reg       */.oCpuMemWr(),
    /*output reg       */.oCpuIoRd (),
    /*output reg       */.oCpuIoWr (),

    // external NEC V20 interface

    /*input            */.iV20Ale  (cpu_ale),
    /*input            */.iV20Sso  (cpu_sso),
    /*input            */.iV20Dtr  (cpu_dtr),     // 1-wr, 0-rd
    /*input            */.iV20Iom  (cpu_iom),     // 1-io, 0-mem
    /*input      [ 7:0]*/.iV20Data (cpu_ad),      // data / low addr 8bits
    /*input      [11:0]*/.iV20Addr (cpu_ah),      // upper addr 12bits
    /*output reg [ 7:0]*/.oV20Data (cpu_data_out),
    /*output reg       */.oV20Clk  (cpu_clk),     // 5Mhz
    /*output reg       */.oV20Dir  (cpu_dir),     // 1(fpga->v20), 0(v20->fpga)
    /*output           */.oV20Reset(cpu_reset)
  );

  assign pmod = {
    /*6*/cpu_dir,
    /*4*/cpu_sso,
    /*2*/cpu_iom,
    /*0*/cpu_clk,
    /*7*/cpu_mem_rd,
    /*5*/cpu_reset,
    /*3*/cpu_dtr,
    /*1*/cpu_ale
  };

endmodule
