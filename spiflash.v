`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:	01/19/2018 
// Created by:		Istvan Hegedus
// Design Name:	SPI flash driver for FPGA plus4
// Module Name:  	spiflash 
// Project Name: 	FPGATED, FPGAplus4
// Target Devices: Xilinx Spartan 3E, 6A
//
// Description: 
//
//	SPI flash driver supports the following flash commands: READ, RDID, RDSR, RDSCUR, PP, SE, WREN, WRDI, CLSR
// Driver usage: 
//	Set the 24 bit flash address (Addr), command (cmd) and if needed the byte to send (din) by the higher level module. 
//	Driver is controlled by active and ack signals. During operation active must be high. A one cycle pulse on ack initiates operation when active is high.
// Busy signal will be active during operation and become inactive as soon as driver has finished the requested operation. 
// If the command implies reading a byte or more, the result will be in dout.
// In case of READ, RDID or PP commands more bytes might need to be read or sent so the driver will be still active when busy signal inactivates. 
// Two possible actions can follow:
// 1. There are more bytes to be read/written so a one cycle ack signal acknowledges that the previous byte was taken and more are needed (active=high, ack=one cycle pulse)
//	2. There are no more bytes to read/write so active must be driven low and a one cycle ack signal informs driver that operation can end (active=low, ack=one cycle pulse)
//
//
// Revision: 1.0
//
//////////////////////////////////////////////////////////////////////////////////
module spiflash(
    input clk,
    input [7:0] din,
    output [7:0] dout,
    input [23:0] Addr,
    input [7:0] cmd,
    input active,
    input ack,
	 input reset,
    output busy,
    output flash_ck,
    output reg flash_cs,
    output flash_si,
    input wire flash_so
    );

initial 
begin
flash_cs=1'b1;	
end

reg [6:0] flash_state=IDLE;
reg [7:0] shiftreg;
reg [2:0] shiftcount=0;
reg flash_clken=1'b0;
reg flash_so_reg;

// FSM states (one hot)
localparam IDLE= 7'b0000001;
localparam CMD = 7'b0000010;
localparam AH  = 7'b0000100;
localparam AM  = 7'b0001000;
localparam AL  = 7'b0010000;
localparam TX  = 7'b0100000;
localparam RX  = 7'b1000000;

localparam PP=8'h02;
localparam READ=8'h03;
localparam WRDI=8'h04;
localparam RDSR=8'h05;
localparam WREN=8'h06;
localparam SE=8'h20;
localparam RDSCUR=8'h2b;
localparam CLSR=8'h30;
localparam RDID=8'h9f;
localparam DP=8'hb9;
localparam RDP=8'hab;

always @(posedge clk)
	begin
	if(reset)
		flash_state<=IDLE;
	else
		case(flash_state)
			IDLE:	begin
					if(active & ack)	// signals start of flash command
						begin
						flash_state<=CMD;
						flash_clken<=1'b1;
						flash_cs<=1'b0;
						shiftreg<=cmd;
						end
					else 
						begin 
						flash_clken<=1'b0;
						end
					end
			CMD:	begin
					shiftreg[7:0]<={shiftreg[6:0],flash_so_reg};	
					shiftcount<=shiftcount+3'b1;
					if(shiftcount==3'b111)
						begin
						if(cmd==READ || cmd==PP || cmd==SE)
							begin
							flash_state<=AH;
							shiftreg<=Addr[23:16];
							end
						else if(cmd==RDSR || cmd==RDSCUR || cmd==RDID)
							begin
							flash_state<=RX;
							end
						else
							begin
							flash_state<=IDLE;			// unknown commands are sent but after that we return to IDLE, don't handle them. Undefined command only commands however work.
							flash_clken<=1'b0;
							flash_cs<=1'b1;
							end
						end
					end
			AH:	begin
					shiftreg[7:0]<={shiftreg[6:0],flash_so_reg};	
					shiftcount<=shiftcount+3'b1;
					if(shiftcount==3'b111)
						begin
						flash_state<=AM;
						shiftreg<=Addr[15:8];
						end
					end
			AM:	begin
					shiftreg[7:0]<={shiftreg[6:0],flash_so_reg};	
					shiftcount<=shiftcount+3'b1;					
					if(shiftcount==3'b111)
						begin
						flash_state<=AL;
						shiftreg<=Addr[7:0];
						end
					end
			AL:	begin
					shiftreg[7:0]<={shiftreg[6:0],flash_so_reg};	
					shiftcount<=shiftcount+3'b1;					
					if(shiftcount==3'b111)
						begin
						if(cmd==PP)
							begin
							flash_state<=TX;
							shiftreg<=din;
							end
						if(cmd==READ)
							begin
							flash_state<=RX;
							end
						if(cmd==SE)
							begin
							flash_state<=IDLE;
							flash_clken<=1'b0;
							flash_cs<=1'b1;
							end
						end
					end
			TX:	begin
					if(flash_clken)					// TX enabled
						begin
						shiftreg[7:0]<={shiftreg[6:0],flash_so_reg};	
						shiftcount<=shiftcount+3'b1;
						if(shiftcount==3'b111)		// pause transfer after 8 bits shift
							begin
							flash_clken<=1'b0;
							end
						end
					else									// TX paused
						begin								
						if(active & ack)				// when byte acknowledged continue with next byte
							begin
							flash_clken<=1'b1;
							flash_state<=TX;
							shiftreg<=din;
							end
						if(~active & ack)				// when byte acknowledged but end signalled, go to IDLE
							begin
							flash_state<=IDLE;
							flash_cs<=1'b1;
							end
						end
					end
			RX:	begin
					if(flash_clken)					// RX enabled
						begin
						shiftreg[7:0]<={shiftreg[6:0],flash_so_reg};	
						shiftcount<=shiftcount+3'b1;
						if(shiftcount==3'b111)		// pause transfer after 8 bits
							begin
							flash_clken<=1'b0;
							end
						end
					else									// RX paused
						begin
						if(active & ack)				// ACK and continue with next byte
							begin
							flash_clken<=1'b1;
							flash_state<=RX;
							end
						if(~active & ack)				// End of RX
							begin
							flash_state<=IDLE;
							flash_cs<=1'b1;
							end
						end
					end
		endcase
 end
 
 // Latch data from Flash on rising edge of flash clock (falling edge of system clock)
always @(negedge clk) begin
	if(flash_clken)
		flash_so_reg<=flash_so;
end

assign busy=flash_clken;
assign flash_si=shiftreg[7];
assign dout=shiftreg;

// Connect FLASH's clock signal. It provides a 180 degree shifted clk
ODDR2 #(
      .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
      .INIT(1'b0),    	// Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("SYNC") 	// Specifies "SYNC" or "ASYNC" set/reset
   ) ODDR2_sdram (
      .Q(flash_ck),		// 1-bit DDR output data
      .C0(clk),   		// 1-bit clock input
      .C1(~clk),   	// 1-bit clock input
      .CE(flash_clken), 			// 1-bit clock enable input
      .D0(1'b0), 			// 1-bit data input (associated with C0)
      .D1(1'b1), 			// 1-bit data input (associated with C1)
      .R(1'b0),   		// 1-bit reset input (no reset)
      .S(1'b0)    		// 1-bit set input (no set)
   );



endmodule
