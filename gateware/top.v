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
    output        ex_cpu_mn
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

  reg [7:0] ram[4096];
  reg [7:0] ram_out;

  initial $readmemh("program.hex", ram);

  always @(posedge pll_clk10) begin
    if (cpu_mem_wr) begin
      ram[ cpu_addr[11:0] ] <= cpu_data_out;
    end
    if (cpu_mem_rd) begin
      cpu_data_in <= ram[ cpu_addr[11:0] ];
    end
  end

  //
  // port latch
  //

  reg [7:0] port;

  always @(posedge pll_clk10) begin
    if (cpu_io_wr) begin
      if (cpu_addr[7:0] == 8'h2b) begin
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
    /*input            */.iClk     (pll_clk10),

    // internal cpu interface

    /*input            */.iCpuRst  (rst),
    /*input      [ 7:0]*/.iCpuData (cpu_data_in),
    /*output reg [ 7:0]*/.oCpuData (cpu_data_out),
    /*output reg [19:0]*/.oCpuAddr (cpu_addr),
    /*output reg       */.oCpuMemRd(cpu_mem_rd),
    /*output reg       */.oCpuMemWr(cpu_mem_wr),
    /*output reg       */.oCpuIoRd (cpu_io_rd),
    /*output reg       */.oCpuIoWr (cpu_io_wr),

    // external NEC V20 interface

    /*input            */.iV20Ale  (ex_cpu_ale),
    /*input            */.iV20Sso  (ex_cpu_sso),
    /*input            */.iV20Dtr  (ex_cpu_dtr),      // 1-wr, 0-rd
    /*input            */.iV20Iom  (ex_cpu_iom),      // 1-io, 0-mem
    /*input      [ 7:0]*/.iV20Data (ex_cpu_ad),       // data / low addr 8bits
    /*input      [11:0]*/.iV20Addr (ex_cpu_ah),       // upper addr 12bits
    /*output reg [ 7:0]*/.oV20Data (ex_cpu_data_out),
    /*output reg       */.oV20Clk  (ex_cpu_clk),      // 5Mhz
    /*output reg       */.oV20Dir  (ex_cpu_data_dir), // 1(fpga->v20), 0(v20->fpga)
    /*output           */.oV20Reset(ex_cpu_reset)
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

  //assign pmod = {
  //  /*6*/ex_cpu_data_dir,
  //  /*4*/ex_cpu_sso,
  //  /*2*/ex_cpu_iom,
  //  /*0*/ex_cpu_clk,
  //  /*7*/cpu_mem_rd,
  //  /*5*/cpu_io_wr,
  //  /*3*/ex_cpu_dtr,
  //  /*1*/ex_cpu_ale
  //};

  //assign pmod = {
  //  /*6*/ex_cpu_ad[6],
  //  /*4*/ex_cpu_ad[4],
  //  /*2*/ex_cpu_ad[2],
  //  /*0*/ex_cpu_ad[0],
  //  /*7*/ex_cpu_ad[7],
  //  /*5*/ex_cpu_ad[5],
  //  /*3*/ex_cpu_ad[3],
  //  /*1*/ex_cpu_ad[1]
  //};

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

endmodule
