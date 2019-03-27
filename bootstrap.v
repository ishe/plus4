`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  Copyright 2013-2018 Istvan Hegedus
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
// Create Date:   19/01/2018
// Design Name: 	Bootstrap
// Module Name:   bootstrap.v 
// Project Name:  FPGATED
// Description: 	This module takes care of uploading the Plus4 ROMs from SPI flash to the FPGA board's memory at startup.
//						It handles the SPI flash of the FPGA board and provides access to flash from the Plus4.
//
//	ROM dataformat inside Xilinx bitfile following FPGA bitstream: 
//
//	[Xilinx FPGA bitstream][3 bytes ROM header|1st ROM data][ROM header|2nd ROM data]...[8'hFF]
//

// ROM header: 1 byte Type followed by 2 bytes Length
// 1st byte (Type)
//				bit 7			0=valid ROM	1=no more ROM in bitstream
//				bit 6			0=Low ROM, 1=High ROM
//				bit 2-5		ROM version number (alternative ROM ID 0-15)
//				bit 0-1		ROM type values: 00=Internal ROM, 01=Function ROM, 10=Cartridge1 ROM, 11=Cartridge2 ROM
//	2nd-3rd bytes (Length)		Length of ROM bitdata in bytes (max 65536 bytes). Little Endian coding (LSB first MSB next)
//	 
// Revision history:
//
//////////////////////////////////////////////////////////////////////////////////
module bootstrap(
	 
	 output wire flash_cs,
	 output wire flash_ck,
	 output wire flash_si,
	 input wire flash_so,
 	 output cs0,
	 output cs1,
	 output reg rw_out,
	 output reg [15:0] addr_out,		// generated address for sdram
	 output [5:0] addr_ext,				// generated address extension for sdram
	 output [7:0] data_out,
	 input reset,
    input boot_enable,
	 output reg boot_done,
	 output reg cfg_done,
	 input phi,
	 input clk,
	 input cs,								// active on $FD98-$FDFF IO range (used for flash commands from Plus4)
	 input rw_in,
	 input [7:0] data_in,
	 input [2:0] addr_in
    );

wire	[23:0] flash_address;
reg	[23:0] flash_address_reg;
reg	[7:0] flash_reg;
reg	[7:0]	data_reg;
reg 	[7:0]	rcv_reg;
wire	[7:0]	flash_cmd;
reg	[7:0]	flash_cmd_reg;
wire	[7:0] flash_data;
reg 	[7:0]	flash_data_reg=8'hff;
reg	flash_active=1'b0;
reg	flash_ack=1'b0;
reg	phi_prev=1'b0;
reg	cs_prev=1'b0;
wire	flash_busy;
reg	[6:0] romtype=7'h0;
reg	[15:0] romlength=16'h0;
reg 	[15:0] countbytes=16'h0;
reg 	[3:0] cfgbyte=4'h0;
reg 	length_h=1'b0;
reg 	[1:0] rxcount=2'b0;


initial begin
boot_done=1'b0;
cfg_done=1'b0;
rw_out=1'b1;
addr_out=16'hffff;
end

//parameter ROM_ADDR=24'h0534A8;							// start of Plus4 ROM data in SPI flash
parameter ROM_ADDR=24'h100000;							// start of Plus4 ROM data in SPI flash
parameter CFG_ADDR=24'h0ff000;							// start of Config data location

reg [8:0] boot_state=IDLE;
localparam IDLE			=	9'b000000001;
localparam LOAD_TYPE		=	9'b000000010;
localparam LOAD_LENGTH	=	9'b000000100;
localparam LOAD_ROM		=	9'b000001000;
localparam LOAD_CFG		=	9'b000010000;
localparam WAIT_CMD		= 	9'b000100000;
localparam SEND			=	9'b001000000;
localparam RECEIVE		=	9'b010000000;
localparam CMD_ONLY		=	9'b100000000;	

localparam PP=8'h02;
localparam READ=8'h03;
localparam RDSR=8'h05;
localparam RDSCUR=8'h2b;
localparam RDID=8'h9f;


spiflash flash(
.clk(clk),
.din(data_reg),
.dout(flash_data),
.Addr(flash_address),
.cmd(flash_cmd),
.active(flash_active),
.ack(flash_ack),
.reset(reset),
.busy(flash_busy),
.flash_ck(flash_ck),
.flash_cs(flash_cs),
.flash_si(flash_si),
.flash_so(flash_so)
);

always @(posedge clk) begin
	phi_prev<=phi;
	cs_prev<=cs;
end

always @(posedge clk)
begin
flash_ack<=1'b0;															// ACK signal default state is low, 
if(reset|~boot_enable)
	begin
	boot_state<=IDLE;
	flash_active<=1'b0;
	end
else if(phi_prev & ~phi)												// FSM synced to phi clock
	begin
		case(boot_state)
			IDLE:
				begin
				if(~boot_done)
					begin
					boot_state<=LOAD_TYPE;
					flash_active<=1'b1;
					flash_ack<=1'b1;
					end
				else
					begin
					boot_state<=WAIT_CMD;
					end
				end
		LOAD_TYPE:
				begin
				if(~flash_busy)
					begin
					rw_out<=1'b1;											 // RAM write cycle must be disabled
					if(flash_data[7])
						begin
						boot_state<=LOAD_CFG;
						boot_done<=1'b1;
						flash_active<=1'b0;
						flash_ack<=1'b1;
						cfgbyte<=4'hf;
						end
					else
						begin
						romtype<=flash_data[6:0];								 // store ROM type 
						flash_ack<=1'b1;
						boot_state<=LOAD_LENGTH;
						length_h<=1'b0;										 // set length lower byte indicator
						end
					end
				end
		LOAD_LENGTH:
				begin
				if(~flash_busy)
					begin
					if(~length_h)											 // ROM length low byte
						begin
						romlength[7:0]<=flash_data;
						flash_ack<=1'b1;
						length_h<=1'b1;									 // next one is length high byte
						end
					else 
						begin													 // ROM length high byte
						romlength[15:8]<=flash_data;
						flash_ack<=1'b1;
						boot_state<=LOAD_ROM;
						countbytes<=16'h0;
						end
					end
				end						
		LOAD_ROM:
				begin
				if(~flash_busy)
					begin
					rw_out<=1'b0;											// RAM write enable
					flash_data_reg<=flash_data;						// Place flash data to databus
					addr_out<=countbytes;								// ROM address
					if(countbytes==romlength)
						begin
						flash_ack<=1'b1;
						boot_state<=LOAD_TYPE;							// After ROM load go back and check whether there are more ROMs or this is the end
						end
					else
						begin
						flash_ack<=1'b1;
						countbytes<=countbytes+16'b1;						// Next byte can come, stay in LOAD_ROM state
						end
					end
				end
		LOAD_CFG:
				begin
				addr_out[15:0]<={12'hFD9,cfgbyte};
				if(~flash_busy)
					begin
					if(cfgbyte==4'hf)
						begin
						flash_active<=1'b1;
						end
					else if(cfgbyte==4'h6)
						begin
						rw_out<=1'b1;
						boot_state<=IDLE;
						flash_active<=1'b0;
						flash_ack<=1'b1;
						cfg_done<=1'b1;
						end
					else
						begin
						rw_out<=1'b0;
						flash_data_reg<=flash_data;							
						end
					flash_ack<=1'b1;
					cfgbyte<=cfgbyte+4'b1;
					end
				end
		WAIT_CMD:													// waiting for command from Plus4 databus
				begin
				flash_data_reg<=8'hff;							// remove the bootstrap data register from databus
				if(cs_prev & ~rw_in & addr_in==3'h0)		// if the CMD register was written
					begin
					flash_active<=1'b1;							// start flash operation
					flash_ack<=1'b1;
					if(data_in==PP)
						begin
						boot_state<=SEND;	
						end
					else if(data_in==RDSR || data_in==RDSCUR || data_in==RDID || data_in==READ)
						begin
						boot_state<=RECEIVE;
						rxcount<=2'b0;							// signals the 1st byte receive
						end
					else
						begin
						boot_state<=CMD_ONLY;				
						end
					end
				end
		SEND:
				begin
				if(cs_prev & ~rw_in & ~flash_busy)
					begin
					case(addr_in)
						3'h0:	begin									// writing to command register stops transfer
								boot_state<=WAIT_CMD;
								flash_active<=1'b0;
								flash_ack<=1'b1;
								end
						3'h4:	begin
								flash_ack<=1;
								end
					endcase	
					end
				end
		RECEIVE:
				begin
				if (~flash_busy)
					begin
					rcv_reg<=flash_data;
					if ((flash_cmd_reg==RDID && rxcount==2'd2) || (cs_prev & ~rw_in & addr_in==3'h0) || flash_cmd_reg==RDSCUR || flash_cmd_reg==RDSR )
						begin
						boot_state<=WAIT_CMD;
						flash_active<=1'b0;
						flash_ack<=1'b1;
						end
					else if(cs_prev & rw_in & addr_in==3'h4)
						begin
						flash_ack<=1'b1;
						rxcount<=rxcount+2'b1;					// rxcount counts the number of received bytes for RDID command
						end
					end		
				end
		CMD_ONLY:
				begin
				if (~flash_busy)
					begin
					boot_state<=WAIT_CMD;
					flash_active<=1'b0;
					flash_ack<=1'b0;
					end		
				end
		endcase
	end
end

// Plus4 flash registers

always @(posedge clk)											// writing flash registers
	begin
	if (cs_prev & ~cs & ~rw_in)							//	take data from databus on the falling edge of cs
		begin
		case(addr_in)
			3'h0:	begin
					flash_cmd_reg<=data_in;
					end
			3'h1:	begin
					flash_address_reg[23:16]<=data_in;
					end
			3'h2:	begin
					flash_address_reg[15:8]<=data_in;
					end
			3'h3:	begin
					flash_address_reg[7:0]<=data_in;
					end
			3'h4: begin
					data_reg<=data_in;
					end
		endcase		
		end
	end
	
always @*															// reading flash registers
	begin
	flash_reg=8'hff;
	if(cs_prev & rw_in)											// cs_prev helps to meet hold time during read
		begin
		case(addr_in)
			3'h0:	begin												
					flash_reg={6'b0,flash_active,flash_busy};				// $FD98
					end
			3'h1:	begin
					flash_reg=flash_address[23:16];			// $FD99
					end
			3'h2:	begin
					flash_reg=flash_address[15:8];			// $FD9A
					end
			3'h3:	begin
					flash_reg=flash_address[7:0];				// $FD9B
					end
			3'h4:	begin
					flash_reg=rcv_reg;							// $FD9C
					end
		endcase
		end
	end


assign cs0=romtype[6];
assign cs1=~romtype[6];
assign addr_ext=romtype[5:0];
assign flash_address=(boot_state==LOAD_TYPE)?ROM_ADDR:
							(boot_state==LOAD_CFG)?CFG_ADDR:
							flash_address_reg;
assign flash_cmd=(cfg_done)?flash_cmd_reg:READ;
assign data_out=flash_reg&flash_data_reg;
endmodule
