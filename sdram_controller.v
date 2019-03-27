`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  Copyright 2013-2016 Istvan Hegedus
//
//  FPGATED is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  FPGATED is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//
// Create Date:   28/09/2016
// Design Name: 	SDRAM controller
// Module Name:   sdram_controller.v
// Project Name:  FPGATED
// Description:	FPGATED SDRAM controller for Papilio Pro board
//
// Revision history:  
// Revision 1.0	
//
// Additional Comments: 
//
//	SDRAM can be used as RAM and ROM. ROM must be uploaded by a bootstrap code from SPI flash or SD card if that is available (no SD card for Papilio Pro). 
// Using special paging we can have more than 64k RAM for the Plus4 and we can change ROM banks. See Csory and Hannes RAM extensions for more details.
//	This sdram controller uses an extended address which is mapped from Plus4 address bus and some additional signals. It is the higher level module's 
// responsibility to do the address mapping and provide an extended 22 bits long address however the controller can distuinguish RAM access from ROM access.
//
// Address mapping in case of RAM access (A15-A0 is Plus4 address bits)
//
//	[A11 - A0]									RAM access row address
// [A13-A12]									SDRAM bank selector
//	[0|6 bits address extension|A15]		RAM access column address. 6 bits extension can be used for RAM expansion (Csory/Hannes)
//	DQM=A14 										High/Low data byte selector on the 16 bits data bus of sdram
//
//	Address mapping in case of ROM access 
//
// [A11 - A0]											ROM access row address
//	[A13-A12]											SDRAM bank selector
//	[1|0|4 bits address extension|ROM type]	ROM access column address. See ROM type values below. 4 bits extension allows 16 ROM versions inside one type.
// DQM=CS0 												high/low ROM selector
//
//	ROM type values: 00=Internal ROM, 01=Function ROM, 10=Cartridge 1, 11=Cartridge 2
// 
//
//////////////////////////////////////////////////////////////////////////////////
module sdram_controller(
    output reg [11:0] sdram_addr,
    inout [15:0] sdram_data,
    output reg [1:0] sdram_dqm,
    output reg [1:0] sdram_ba,
    output sdram_we,
    output sdram_ras,
    output sdram_cas,
    output sdram_cs,
	 output reg sdram_cke,
    input clk,
	 input [15:0] plus4_addr,
	 input [5:0] plus4_addrext,					// RAM/ROM address extension bits 
    input plus4_ras,
    input plus4_cas,
    input plus4_rw,
    input plus4_cs0,
	 input plus4_cs1,
    input [7:0] ram_datain,
    output [7:0] ram_dataout,
	 output reg initdone							// signals when sdram init is done
    );

reg [7:0] initcycle=8'd182;					// this is the duration of the whole sdram initialization sequence (units are TED double clk cycles)
reg [3:0] cycle=0;								// sdram cycle counter
reg plus4_ras_prev=1;
reg [3:0] sdram_cmd=4'b0000;
reg [7:0] dataout;

localparam CMD_INHIBIT		= 4'b1xxx;
localparam CMD_LOADMODE		= 4'b0000;
localparam CMD_AUTOREFRESH = 4'b0001;
localparam CMD_PRECHARGE 	= 4'b0010;
localparam CMD_ACTIVE		= 4'b0011;
localparam CMD_WRITE			= 4'b0100;
localparam CMD_READ			= 4'b0101;
localparam CMD_NOP			= 4'b0111;


localparam BURST_LENGTH 	=	3'b000;
localparam BURST_TYPE 		=	1'b0;
localparam CAS_LATENCY 		=	3'b010;			// CL=2
localparam WRITE_BURST 		= 	1'b1;				// single location access
localparam MODE =	{3'b000, WRITE_BURST, 2'b00, CAS_LATENCY, BURST_TYPE, BURST_LENGTH};

assign sdram_cs	=	sdram_cmd[3];
assign sdram_ras	=	sdram_cmd[2];
assign sdram_cas	=	sdram_cmd[1];
assign sdram_we	=	sdram_cmd[0];


initial
 begin
 sdram_cke=0;
 initdone=0;
 end

always @(posedge clk)
	begin
	if(cycle==4'd14)
		begin
		if(initcycle!=0)
			initcycle<=initcycle-1'b1;
		else initdone<=1'b1;						// for clean startup synchronize initdone signal to memory cycle beginning
		end
	end


always @(posedge clk)						// memory cycle counter
 begin
	plus4_ras_prev<=plus4_ras;
	if(~plus4_ras & plus4_ras_prev)		// RAS falling edge detection
		cycle<=0;								// synchronize memory cycle counter to RAS beginning ( 1 cycle delay!)
	else cycle<=cycle+4'b1;
 end


always @(posedge clk)
 begin
 sdram_cmd<=CMD_INHIBIT;
 if(!initdone)									// sdram initialization
	begin
	sdram_ba<=2'b00;
	sdram_dqm<=2'b00;
	if(initcycle==9'd90)						// enable sdram clock at about half of the 100us wait time
		sdram_cke<=1;
	else	if(initcycle==9'd1)				// after 100us start the setup sequence
		case (cycle)
			0:	begin
				sdram_addr<=12'b010000000000;
				sdram_cmd<=CMD_PRECHARGE;
				end
			2: sdram_cmd<=CMD_AUTOREFRESH;
			4: sdram_cmd<=CMD_AUTOREFRESH;
			6:	begin
				sdram_addr<=MODE;
				sdram_cmd<=CMD_LOADMODE;
				end
			default: sdram_cmd<=CMD_NOP;
		endcase
	end	
 else	begin										// normal sdram operation after initialization
		sdram_cmd<=CMD_NOP;
		sdram_dqm<=2'b11;									// by default we mask output
		case (cycle)
		15:	begin											// activate row in each CPU cycle
					sdram_addr<=plus4_addr[11:0];
					sdram_ba<=plus4_addr[13:12];
					sdram_cmd<=CMD_ACTIVE;
				end
		1: 	begin
				if(plus4_rw)														// READ								
					begin
					sdram_dqm<=2'b00;												// for reads we don't need to mask output as mux and data latching will take care of getting proper data
					if(~plus4_cas)																				// RAM read
						begin
						sdram_addr<={4'b0100,1'b0,plus4_addrext,plus4_addr[15]};
						sdram_cmd<=CMD_READ;
						end
					else if(~plus4_cs0|~plus4_cs1)														// ROM read
						begin
						sdram_addr<={4'b0100,2'b10,plus4_addrext};
						sdram_cmd<=CMD_READ;
						end
					end
				end
		3:		begin
				if(plus4_rw)																					// if READ command was issued, latch result 2 Clocks later (CL=2)
					begin
					if(~plus4_cas)																				// RAM data latch									
						dataout<=(plus4_addr[14])?sdram_data[15:8]:sdram_data[7:0];
					else if(~plus4_cs0|~plus4_cs1)														// ROM data latch
						dataout<=(plus4_cs0)?sdram_data[15:8]:sdram_data[7:0];
					end
				end
		4:		if(plus4_cas&plus4_cs0&plus4_cs1)														// if row was activated in vain because of TED read/write or io read/write close row
					sdram_cmd<=CMD_PRECHARGE;																// it must be done not earlier than cycle 4 because write CAS activates later than read CAS
		6:		if(~plus4_rw)																					// if write cycle
					begin
					if(~plus4_cas)																				// RAM write
						begin
						sdram_addr<={4'b0100,1'b0,plus4_addrext,plus4_addr[15]};
						sdram_dqm<=(plus4_addr[14])?2'b01:2'b10;
						sdram_cmd<=CMD_WRITE;
						end
					else if(~plus4_cs0|~plus4_cs1)														// ROM write. It is only used at the initial ROM upload. In normal operatin this should not happen.
						begin
						sdram_addr<={4'b0100,2'b10,plus4_addrext};
						sdram_dqm<=(plus4_cs0)?2'b01:2'b10;
						sdram_cmd<=CMD_WRITE;
						end
					end
		10:	sdram_cmd<=CMD_AUTOREFRESH;
		
		endcase
		end
 end

// assign ram_dataout=(~plus4_cas&plus4_rw)?dataout:8'hff;											// data out assignment when only RAM is used from sdram
assign ram_dataout=(plus4_rw&(~plus4_cas|~plus4_cs0|~plus4_cs1))?dataout:8'hff;			// data out assignment when RAM and ROM is used from sdram

assign sdram_data=(sdram_cmd==CMD_WRITE)?{ram_datain,ram_datain}:16'bZZZZZZZZZZZZZZZZ;



endmodule

