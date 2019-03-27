`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   13:14:00 01/18/2018
// Design Name:   spiflash
// Module Name:   C:/Users/ishe/Documents/Cloud/FPGAdev/Plus4/flashtest.v
// Project Name:  Plus4
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: spiflash
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module flashtest;

	// Inputs
	reg clk;
	reg [7:0] din;
	reg [23:0] Addr;
	reg [7:0] cmd;
	reg active;
	reg ack;
	reg reset;
	wire flash_so;

	// Outputs
	wire [7:0] dout;
	wire busy;
	wire flash_ck;
	wire flash_cs;
	wire flash_si;

	// Instantiate the Unit Under Test (UUT)
	spiflash uut (
		.clk(clk), 
		.din(din), 
		.dout(dout), 
		.Addr(Addr), 
		.cmd(cmd), 
		.active(active), 
		.ack(ack), 
		.reset(reset), 
		.busy(busy), 
		.flash_ck(flash_ck), 
		.flash_cs(flash_cs), 
		.flash_si(flash_si), 
		.flash_so(flash_so)
	);
	initial begin
		// Initialize Inputs
		clk = 0;
		din = 0;
		Addr = 24'h000000;
		cmd = 8'h00;
		active = 0;
		ack = 0;
		reset = 0;
		
		// Wait 100 ns for global reset to finish
		#100;
		// Add stimulus here
		Addr = 24'h3fe512;
		cmd=8'h03;
		active=1;
		file=$fopen("fakerom.bin","rb");
		
	end

// 28.288 Mhz	
always
		begin
#17.675	clk<=~clk;
		end
//--------------------------------------------------------------			

reg [2:0] bytecount=0;
reg [2:0] bitcount=7;
reg [2:0] cbitcount=0;
reg [7:0] flashreg=8'h00;
integer file;
reg command=1;

always @(negedge flash_ck) begin
	if (~flash_cs) begin
		if (~command) begin
			bitcount<=bitcount+1;
			if(bitcount==7)
				flashreg<=$fgetc(file);
			else flashreg[7:0]<={flashreg[6:0],1'b0};		
		end

	end
end

always @(posedge flash_ck) begin
	if(command) begin
		cbitcount<=cbitcount+1;
		if(cbitcount==7)
			if(bytecount==3)
				command<=0;
			else	bytecount=bytecount+1;
	end
end

assign flash_so=flashreg[7];	
		
always @(negedge active) begin
	$fclose(file);
end
		
      
endmodule

