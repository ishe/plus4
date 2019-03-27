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
// 
// Create Date:    12:02:05 16/09/2016 
// Design Name: 	 Commodore Plus 4 in an FPGA
// Module Name:    PLUS4_testbench.v
// Project Name: 	 FPGATED Papilio Pro edition
//
// Description: 	
//	This module is the testbench for FPGATED Plus4.v
// 
//
// Revision history: 
// 0.1   16.09.2016			 Testbench created
//
//	Comments:                This module is based on c16_testbench.v which is part of the original FPGATED design and it makes use of Papilio Pro platform's sdram.
//
//////////////////////////////////////////////////////////////////////////////////

module Plus4_testbench;
	
	reg CLK28;
	wire phi0;
	reg phi0_prev;
	reg phi_prev;
	reg sreset=0;
	reg RESET=0;
	reg [7:0] port_in=0;
	wire [7:0] port_out;
	wire [7:0] datain;
	wire aec;
	wire rdy;
	reg enable=0;


	wire irq_n;
   wire [7:0] dataout;
	wire [15:0] addr;
	wire RW;
	wire [6:0] color;
	wire [3:0] red,green,blue;
	wire csync;
	wire RAS,CAS,mux,cs0,cs1;
	
	wire [15:0] plus4_addr,ted_addr,cpu_addr;
	wire [7:0]  plus4_data,ted_data,ram_data,A,cpu_data,basic_data,kernal_data,rom_data;
	wire [7:0] keyboard_row,keyport_data,key,kbus;
	reg [7:0] romreg_data;
	reg  [7:0] plus4_datalatch=0;
	reg [7:0] keyscancode;
	wire [6:0] plus4_color;
	reg [12:0] resetcounter=0;
	reg [15:0] plus4_addrlatch=0;
	wire keyreset;
	wire [4:0] joy0port,joy1port;				// keyboard emulated joystick ports
	wire [4:0] joy0emu,joy1emu;				// keyboard emulated joystick ports masked by select lines 
	reg keyreceived=0;
	wire cpuenable;
	reg pla_arm;
	wire FD3x;
	wire FDDx;
	reg  FDDx_prev=0;
	wire FD1x;
	wire FD0x;
	reg [3:0] romselect=0;						// Plus4/C16 motherboard U21 ROM selector register
	reg [3:0] Kernalver=4'h0;					// Kernal ROM alternative version selector 1-16
	reg [3:0] Basicver=4'h0;					// Basic ROM alternative version selector 1-16
	reg [3:0] FunctionLver=4'h0;				// Function ROM alternative version selector 1-16 (Low)
	reg [3:0] FunctionHver=4'h0;				// Function ROM alternative version selector 1-16 (High)
	reg [3:0] C1Lver=4'h0;						// Cartridge ROM1 alternative version selector 1-16 (Low)
	reg [3:0] C1Hver=4'h0;						// Cartridge ROM1 alternative version selector 1-16 (High)	
	reg [3:0] C2Lver=4'h0;						// Cartridge ROM2 alternative version selector 1-16 (Low)
	reg [3:0] C2Hver=4'h0;						// Cartridge ROM2 alternative version selector 1-16 (High)	
	reg [3:0] romversion;						// Addressed ROM's version (1-16)
	reg [5:0] romaddrext;						// ROM address extension 4M ROM area (see sdram controller)
	reg [5:0] ramaddrext=6'b000000;			// RAM address extension 4M RAM (Hannes/Csory)
	wire [5:0] plus4_addrext;
	reg romconfig=0;								// ROM config mode enables a special kernal to configure ROM versions
	reg romconfreset=0;
	reg FD9x_prev=0;
	wire boot_cs;
	
	wire [11:0] SDRAM_ADDR;
	wire [15:0] SDRAM_DATA;
	wire SDRAM_DQML;
	wire SDRAM_DQMH;
	wire [1:0] SDRAM_BA;
	wire SDRAM_nWE;
	wire SDRAM_nCAS;
	wire SDRAM_nRAS;
	wire SDRAM_CS;
	wire SDRAM_CKE;

	wire FLASH_SI;
	wire FLASH_SO;
	wire FLASH_CK;
	wire FLASH_CS;
	wire boot_cs0;
	wire boot_cs1;
	wire boot_rw;
	wire [15:0] boot_addr;
	wire [5:0] boot_addrext;
	wire [7:0] boot_data;
	wire [7:0] config_data;
	wire boot_done;
	
	wire sdram_cs0;
	wire sdram_cs1;
	wire sdram_rw;
	wire [15:0] ram_addr;
	wire [5:0] sdram_addrext;
	wire [7:0] sdram_datain;
	
	initial begin
		// Initialize Inputs
		CLK28=0;
		keyscancode=7'hff;
		keyreceived=1;
		file=$fopen("fakerom.bin","rb");
		// Wait for global reset to finish
		#150000;
		port_in=8'hff;
		
		// Add stimulus here
						
	end
	
	// 8501 CPU
	mos8501 cpu (
		.clk(CLK28), 
		.reset(sreset), 
		.enable(cpuenable),  
		.irq_n(irq_n), 
		.data_in(plus4_data), 
		.data_out(cpu_data), 
		.address(cpu_addr),
		.gate_in(mux),
		.rw(RW),							// rw=high read, rw=low write
		.port_in(port_in),
		.port_out(port_out),
		.rdy(rdy),
		.aec(aec)
	);

  // TED
	ted mos8360(
		.clk(CLK28),
		.addr_in(plus4_addr),
		.addr_out(ted_addr),
		.data_in(plus4_data),
		.data_out(ted_data),
		.rw(RW),
		.cpuclk(phi0),
		.color(color),
		.csync(csync),
		.irq(irq_n),
		.ba(rdy),
		.mux(mux),
		.ras(RAS),
		.cas(CAS),
		.cs0(cs0),
		.cs1(cs1),
		.aec(aec),
		.k(kbus),
		.snd(sound),
		.cpuenable(cpuenable)
//		.pal(pal)
		);

// SDRAM controller
 sdram_controller ram_ctrl(
		.sdram_addr(SDRAM_ADDR),
		.sdram_data(SDRAM_DATA),
		.sdram_dqm({SDRAM_DQMH,SDRAM_DQML}),
		.sdram_ba(SDRAM_BA),
		.sdram_we(SDRAM_nWE),
		.sdram_ras(SDRAM_nRAS),
		.sdram_cas(SDRAM_nCAS),
		.sdram_cs(SDRAM_CS),
		.sdram_cke(SDRAM_CKE),
		.clk(CLK28),
		.plus4_addr(ram_addr),
		.plus4_addrext(sdram_addrext),								
		.plus4_ras(RAS),
		.plus4_cas(CAS),
		.plus4_rw(sdram_rw),
		.plus4_cs0(sdram_cs0),
		.plus4_cs1(sdram_cs1),
		.ram_datain(sdram_datain),
		.ram_dataout(ram_data),
		.initdone(raminitdone)
 );

// SDRAM connection multiplexers

assign ram_addr=(cfg_done)?plus4_addr:boot_addr;
assign sdram_addrext=(boot_done)?plus4_addrext:boot_addrext;
assign sdram_cs0=(boot_done)?cs0:boot_cs0;
assign sdram_cs1=(boot_done)?cs1:boot_cs1;
assign sdram_rw=(boot_done)?RW:boot_rw;
assign sdram_datain=(boot_done)?plus4_data:boot_data;

assign plus4_addrext=(~cs0|~cs1)?romaddrext:ramaddrext;	// set ROM or RAM address extension

mt48lc4m16a2 sdram(
	.Dq(SDRAM_DATA),
	.Addr(SDRAM_ADDR),
	.Ba(SDRAM_BA),
	.Clk(~CLK28),
	.Cke(SDRAM_CKE),
	.Cs_n(SDRAM_CS),
	.Ras_n(SDRAM_nRAS),
	.Cas_n(SDRAM_nCAS),
	.We_n(SDRAM_nWE),
	.Dqm({SDRAM_DQMH,SDRAM_DQML})
	);	 

// Kernal rom (testbench)
	kernal_rom kernal(
		.clk(CLK28),
		.address_in(plus4_addr[13:0]),
		.data_out(kernal_data),
		.cs(cs1)
		);

// Basic rom (testbench)
	basic_rom basic(
		.clk(CLK28),
		.address_in(plus4_addr[13:0]),
		.data_out(basic_data),
		.cs(cs0)
		);
	
// Color decoder to 12bit RGB	(testbench)
colors_to_rgb colordecode(
		.clk(CLK28),
		.color(color),
		.red(red),
		.green(green),
		.blue(blue));

// keyboard part (testbench)

/*
ps2receiver ps2rcv(
    .clk(CLK28),
    .ps2_clk(ps2clk),
    .ps2_data(ps2dat),
    .rx_done(keyreceived),
    .ps2scancode(keyscancode)
    );
*/

c16_keymatrix keyboard(
	 .clk(CLK28),
    .scancode(keyscancode),
    .receiveflag(keyreceived),
	 .row(keyboard_row),
    .kbus(key),
	 .keyreset(keyreset),
	 .joy0(joy0port),
	 .joy1(joy1port),
	 .esc(key_esc)
    );

mos6529 keyport(
	 .clk(CLK28),
    .data_in(plus4_data),
    .data_out(keyport_data),
    .port_in(8'hff),
    .port_out(keyboard_row),
    .rw(RW),
    .cs(FD3x)
    );

// Bootstrap uploads ROM images from FPGA flash chip to SDRAM (testbench)

 bootstrap boot(
	// SPI flash signals
    .flash_cs(FLASH_CS),
	 .flash_ck(FLASH_CK),
	 .flash_si(FLASH_SI),
	 .flash_so(FLASH_SO),
	// generated ROM signals
	 .cs0(boot_cs0),
	 .cs1(boot_cs1),
	 .rw_out(boot_rw),
	 .addr_out(boot_addr),				
	 .addr_ext(boot_addrext),
	 .data_out(boot_data),
	 
	 .reset(1'b0),
	 .boot_enable(raminitdone),
	 .boot_done(boot_done),
	 .cfg_done(cfg_done),
	 .phi(phi0),
	 .clk(CLK28),
	 // signals for SPI FLASH communication via Plus4 bus
	 .cs(boot_cs),
	 .rw_in(RW),
	 .data_in(plus4_data),
	 .addr_in(plus4_addr[2:0])
    );


// PLA functions (testbench)

always @(posedge CLK28) begin							// arm function needs to be registered
	pla_arm<=mux|(~RAS&phi0&pla_arm);
	end

assign KERN=(plus4_addr[15:8]==8'hfc)?1'b1:1'b0;
assign FD3x=((plus4_addr[15:4]==12'hfd3) & pla_arm & phi0 & ~RAS)?1'b1:1'b0;	// KEYPORT
assign FDDx=((plus4_addr[15:4]==12'hfdd) & pla_arm & phi0 & ~RAS)?1'b1:1'b0;	// ADDR CLK
assign FD0x=((plus4_addr[15:4]==12'hfd0) & phi0)?1'b1:1'b0;  						// 6551
assign FD1x=((plus4_addr[15:4]==12'hfd1) & pla_arm & phi0 & ~RAS)?1'b1:1'b0;  // 6529
assign phi2=~RAS & pla_arm & phi0;															// PHI2 CLK not used at the moment
assign FD2x=((plus4_addr[15:4]==12'hfd2) & phi0 & ~RAS); 							// SPEECH $FD2X is not used in Plus4 (used for Commodore 364)
assign FD9x=((plus4_addr[15:4]==12'hfd9) & phi0 & ~RAS);								// FPGATED configuration register

// ROM MMU (testbench)

always @(posedge CLK28) begin									// Plus4 motherboard ROM selector register (U21)
	FDDx_prev<=FDDx;
	if(~FDDx_prev&FDDx&~RW)
		romselect<=plus4_addr[3:0];
	end

always @*	begin													// generating ROM address extension for different ROM versions (based on motherboard schematic)
		if(~cs0) begin												// low ROM
			case(romselect[1:0])									// based on romselect register set romversion to the active rom version (version 1-16)
					2'b00:	romversion=Basicver;				
					2'b01:	romversion=FunctionLver;
					2'b10:	romversion=C1Lver;
					2'b11:	romversion=C2Lver;
			endcase
			romaddrext={romversion,romselect[1:0]};
		end
		else begin													// high ROM
				case(romselect[3:2])
					2'b00:	romversion=Kernalver;
					2'b01:	romversion=FunctionHver;
					2'b10:	romversion=C1Hver;
					2'b11:	romversion=C2Hver;
				endcase	
				romaddrext=(romconfig)?{4'hf,2'b00}:(KERN)?{Kernalver,2'b00}:{romversion,romselect[3:2]};
		end
end

// ROM config mode flag 

always @(posedge CLK28)
	begin
	if(sreset&key_esc)					// activate ROM configuration mode when ESC key is pressed during bootstrap or Romconfig Kernal is active
		romconfig<=1;
	else if(sreset)						// inactivate ROM configuration mode at beginning of hard reset
		romconfig<=0;
	end
	


// FPGATED ROM config register  (could be placed to a separate module)

always @(posedge CLK28)
	begin
	FD9x_prev<=FD9x;
	phi0_prev<=phi0;
	end


always @(posedge CLK28) begin
	romreg_data<=8'hff;
	romconfreset<=1'b0;
	if(FD9x & RW) begin																// ROM and FPGATED config registers read					
			case(plus4_addr[3:0])
				4'h0:	romreg_data<={Kernalver,Basicver};
				4'h1:	romreg_data<={FunctionHver,FunctionLver};
				4'h2:	romreg_data<={C1Hver,C1Lver};
				4'h3:	romreg_data<={C2Hver,C2Lver};
				default:romreg_data<=8'hff;
			endcase
		end
	// ROM and FPGATED config registers write (only allowed when RomConfig mode is enabled)
	// this part is connected to bootstrap data and address buses during FPGATED configuration in order to load initial values
	// during normal operation it is connected to Plus4 data and address buses so it can be modified via Plus4 bus cycles
	else if((FD9x_prev & ~FD9x & ~RW & romconfig) || (boot_done & ~cfg_done & phi0_prev & ~phi0 & ~boot_rw ))
		begin																				
			case(ram_addr[3:0])														// ram_addr is boot_addr during bootstrap, plus4_address after FPGTAED is configured
				4'h0: begin
						Kernalver<=config_data[7:4];								// config_data is boot_data during bootstrap, plus4_datalatch after FPGATED is configured
						Basicver<=config_data[3:0];
						end
				4'h1:	begin
						FunctionHver<=config_data[7:4];
						FunctionLver<=config_data[3:0];
						end
				4'h2:	begin
						C1Hver<=config_data[7:4];
						C1Lver<=config_data[3:0];
						end
				4'h3:	begin
						C2Hver<=config_data[7:4];
						C2Lver<=config_data[3:0];
						end
				4'h4: begin														// Config register 1
				// add config register write here
						end
				4'h5:	begin														// Config register 2
				// add config register write here
						end
				4'h7: begin
						romconfreset<=1'b1;									// Reset system when writing to this address
						end
			endcase
		end
end

assign boot_cs=FD9x&plus4_addr[3]&(~cfg_done|romconfig);				// FPGATED boot chipselect signal 
assign config_data=(cfg_done)?plus4_datalatch:boot_data; 			// data for config registers write is taken from Plus4 databus or boot databus


// Plus4 reset circuit (testbench)

always @(posedge CLK28)		// reset tries to emulate the length of a real reset
	begin
	if(RESET|keyreset|romconfreset)		// reset can be triggered by reset button or CTRL+ALT+DEL from keyboard
		begin
		resetcounter<=0;		// start reset length counter
		sreset<=1;				// set synchronous reset for CPU
		end
	else begin
		if(resetcounter==24'd5000) begin
			if(boot_done)
				sreset<=0;			// end of reset after approximately 590ms
			end
		else begin
			resetcounter<=resetcounter+1;
			sreset<=1;
			end
		end
	end	

// Motherboard bus connections (testbench)

assign rom_data=kernal_data&basic_data;


assign plus4_addr=(~mux)?plus4_addrlatch:cpu_addr&ted_addr;
assign plus4_data=(mux)?plus4_datalatch:cpu_data&ted_data&keyport_data&romreg_data&((~cs0|~cs1)?rom_data:ram_data)&boot_data;


always @(posedge CLK28)
	begin
	plus4_datalatch<=plus4_data;
	plus4_addrlatch<=plus4_addr;
	end

// Joystick and Keyboard connection to keybus (testbench)

assign joy0emu=(~plus4_data[2])?joy0port:5'b11111;			// keyboard emulated joy0 port is allowed to kbus only when its select line is active (D2 bit)
assign joy1emu=(~plus4_data[1])?joy1port:5'b11111;			// keyboard emulated joy1 port is allowed to kbus only when its select line is active (D1 bit)

assign kbus={key[7]&joy1emu[4],key[6]&joy0emu[4],key[5:4],key[3]&joy0emu[3]&joy1emu[3],key[2]&joy0emu[2]&joy1emu[2],key[1]&joy0emu[1]&joy1emu[1],key[0]&joy0emu[0]&joy1emu[0]};

// connect IEC bus	
// this part is left out from TB


// Generating system clock 28.288 Mhz
	
always
		begin
#17.675	CLK28<=~CLK28;
		end

always @(plus4_addr)
	begin
	if (plus4_addr == 16'he6e2)
		$finish;
	end

//--------------------------------------------------------------			
// Bootstrap stimulus

reg [2:0] bytecount=0;
reg [2:0] bitcount=7;
reg [2:0] cbitcount=0;
reg [7:0] flashreg=8'h03;
integer file;
reg command=1;

always @(negedge FLASH_CK) begin
	if (~FLASH_CS) begin
		if (~command) begin
			bitcount<=bitcount+1;
			if(bitcount==7)
				flashreg<=$fgetc(file);
			else flashreg[7:0]<={flashreg[6:0],1'b0};		
		end

	end
end

always @(posedge FLASH_CK) begin
	if(command) begin
		cbitcount<=cbitcount+1;
		if(cbitcount==7)
			if(bytecount==3)
				command<=0;
			else	bytecount=bytecount+1;
	end
end

assign FLASH_SO=flashreg[7];	
		
always @(posedge cfg_done) begin
	$fclose(file);
end
		


endmodule
