`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
//
// Create Date:   20:27:09 10/25/2016
// Design Name:   bootstrap testbench
// Module Name:   C:/Users/ISHE/Documents/Cloud/FPGAdev/Plus4/boottest.v
// Project Name:  Plus4
// Description: 
//
// Verilog Test Fixture created for testing FPGATED bootstrap function
//
// Dependencies: A binary rompack file must exist.
// 
// Revision:
// 1.0
// 
////////////////////////////////////////////////////////////////////////////////

module boottest;

	// Inputs
	wire flash_so;
	reg ram_initdone;
	reg read_enable;
	reg clk;
	reg [3:0] phicounter=0;

	// Outputs
	wire flash_cs;
	wire flash_ck;
	wire flash_si;
	wire cs0;
	wire cs1;
	wire rw;
	wire [15:0] address_out;
	wire [5:0] address_ext;
	wire [7:0] dataout;
	wire bootstrap_done;

	// Instantiate the Unit Under Test (UUT)
	bootstrap uut (
		.flash_cs(flash_cs), 
		.flash_ck(flash_ck), 
		.flash_si(flash_si), 
		.flash_so(flash_so),
		.cs0(cs0), 
		.cs1(cs1), 
		.rw_out(rw), 
		.addr_out(address_out), 
		.addr_ext(address_ext),
		.data_out(dataout), 
		.reset(1'b0),
		.boot_enable(read_enable),
		.boot_done(bootstrap_done),
		.phi(phicounter[3]),  
		.clk(clk),
		.cs(),		
		.rw_in(),
		.data_in(),
		.addr_in()
	);


	initial begin
		// Initialize Inputs
		read_enable = 0;
		clk = 0;
		file=$fopen("fakerom2.bin","rb");
		
		// Wait 100 ns for global reset to finish
		#100;
		// Add stimulus here
		ram_initdone = 1;  
		read_enable=1;
	end
	
// 28.288 Mhz	
always
		begin
#17.675	clk<=~clk;
		end

always @(posedge clk)
			begin
			phicounter<=phicounter+1;
			end
//--------------------------------------------------------------			

reg [2:0] bytecount=0;
reg [2:0] bitcount=7;
reg [2:0] cbitcount=0;
reg [7:0] flashreg=8'h03;
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
		
always @(posedge bootstrap_done) begin
	$fclose(file);
end
		
endmodule
