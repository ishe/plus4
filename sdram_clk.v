`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date:	21:49:28 04/09/2017 
// Design Name:	Plus4
// Module Name:	sdram_clk 
// Project Name:	FPGATED
// Target Devices: Xilinx Spartan6
// Description:	Xilinx specific SDRAM clock output generator using DDR2 register 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module sdram_clk(
    input clk,
    output sdram_clk
    );

ODDR2 #(
      .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
      .INIT(1'b0),    	// Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("SYNC") 	// Specifies "SYNC" or "ASYNC" set/reset
   ) ODDR2_sdram (
      .Q(sdram_clk),		// SDRAM's clock output from FPGA
      .C0(clk),   		// FPGA's global clock
      .C1(~clk),	   	// FPGA's global clock
      .CE(1'b1), 			// 1-bit clock enable input
      .D0(1'b0), 			// 1-bit data input (associated with C0)
      .D1(1'b1), 			// 1-bit data input (associated with C1)
      .R(1'b0),   		// 1-bit reset input (no reset)
      .S(1'b0)    		// 1-bit set input (no set)
   );

endmodule
