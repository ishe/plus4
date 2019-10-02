# plus4
FPGATED based Plus4 implementation using Papilio Pro platform


 This is FPGAPlus4 based on my FPGATED verilog core.
 
 v1.0	27/03/2019	release
 
 v1.1rc	02/03/2019	Using TED core v1.1 which fixes FLI problems. DMA counter (videocounter) latch conditions are fixed. Now FLI compatible.

 Features:
 - sdram controller synchronized to Plus4 phi0 clock
 - multiple rom images stored in onboard sdram
 - bootstrap code uploads rom images from FPGA SPI config flash
 - ROM images stored in FPGA config flash together with bitstream
 - a config kernal written in assembly (source not yet included)
 - multiple 6502 cores (T65 or FPGA64) choosable before synthesis
 - onboard SPI flash accessible from Plus4 
 - rom config registers and SPI flash base I/O address $fd90
 
 The sdram controller contains an address extension mechanism for future ram expansions and current ROM images store.
 This part still needs documentation, however the controller's source file comment already contains valuable information
 on the address extension format.
 The bootstrap mechanism and the rompack format stored in SPI flash has also some information in the bootstrap source header,
 however it needs some more documentation as well.
 
 More information will be added
