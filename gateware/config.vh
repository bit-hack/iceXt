/*     _          _  ________
 *    (_)_______ | |/ /_  __/
 *   / / ___/ _ \|   / / /
 *  / / /__/  __/   | / /
 * /_/\___/\___/_/|_|/_/
 *
**/


//`define CFG_ENABLE_10MHZ
//`define CFG_ENABLE_16MHZ
`define CFG_ENABLE_20MHZ

//`define CFG_ENABLE_ADLIB

`ifdef CFG_ENABLE_10MHZ
`define CLOCK_SPEED 10000000
`endif

`ifdef CFG_ENABLE_16MHZ
`define CLOCK_SPEED 16666666
`endif

`ifdef CFG_ENABLE_20MHZ
`define CLOCK_SPEED 20000000
`endif
