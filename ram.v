`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: 
// 
// Create Date:    
// Design Name: 
// Module Name:    ram 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: RAM used for simulation purposes only
//
// Dependencies: This is only for simulation. Real DRAM is on FPGATED board
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module ram(
    input wire [7:0] address,
	 input wire ras,
	 input wire cas,
    input wire [7:0] data_in,
    output wire [7:0] data_out,
    input wire rw
    );

reg [7:0] memory[65535:0];
reg [7:0] q;
reg [15:0] ramaddress;
integer i;

always @(negedge ras)
		ramaddress[7:0]=address;

always @(negedge cas)
		begin
		ramaddress[15:8]=address;
		if (rw==0)
			memory[ramaddress]=data_in;
		else 
			q=memory[ramaddress];
		end
		
assign data_out=(!cas && rw)?q:8'hff;

initial begin
	for (i=0;i<=65535;i=i+2)
		begin
		memory[i]=8'h00;
		memory[i+1]=8'hff;
		end
	end	
endmodule
