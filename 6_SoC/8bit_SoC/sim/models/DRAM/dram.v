`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/18 00:33:12
// Design Name: 
// Module Name: dram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dram(input		ck_t, ck_c,
	input		cke,
	input		csn, actn,
	input [1:0]	bg, ba,
	input [17:0] a,	//rasn 16, casn 15, wen 14, bcn 12, ap 10

	inout [7:0]	dq,
	inout		dqs_t, dqs_c
);
	parameter [4:0] ACT=5'b00111, WR=5'b01100, RD=5'b01101,MRS=5'b01000;	//opcode
	parameter	tRCD=9,tRP=8;
	
	reg [3:0] 	tCWL, tCL;
	wire	rasn = a[16];
	wire	casn = a[15];
	wire	wen  = a[14];

	wire [4:0] opcode = {csn,actn,rasn,casn,wen};

	reg [3:0] 	row, col;
	reg 		write_op, read_op;
	reg [4:0] 	cnt;
	reg [63:0] 	curr_data;
	reg 		data_write;

	reg  [7:0] 	dq_o;
	wire		dq_oe;
	wire [7:0] 	dq_i;

	assign dq = dq_oe ? dq_o: 'bZ;
	assign dq_i = dq;

	reg [63:0] mem[15:0][15:0];

	always @(posedge ck_t) begin
		case (opcode) 
			ACT: 	row <= a[3:0];
			WR,RD: 	col <= a[3:0];
		endcase
	end

	always @(posedge ck_t) begin
			 if (opcode == ACT) write_op <= 0;
		else if (opcode == WR)  write_op <= 1;
		else if (cnt == tCWL+4) write_op <= 0;

			 if (opcode == ACT) read_op <= 0;
		else if (opcode == RD)  read_op <= 1;
		else if (cnt == tCL +4) read_op <= 0;
	end

	always @(posedge ck_t)
			 if (opcode == ACT) cnt <= 0;
		else if (opcode == WR || opcode == RD) cnt <= 1;
		else if (write_op) cnt <= cnt == tCWL+4? 0: cnt + 1;
		else if (read_op)  cnt <= cnt == tCL +4? 0: cnt + 1;

	always @(posedge dqs_c)
		if (cnt == tCWL) 	curr_data[ 7:0 ] <= dq_i;
		else if (cnt == tCWL+1) 	curr_data[23:16] <= dq_i;
		else if (cnt == tCWL+2) 	curr_data[39:32] <= dq_i;
		else if (cnt == tCWL+3) 	curr_data[55:48] <= dq_i;

	always @(posedge dqs_t)
		if (cnt == tCWL) 	curr_data[15:8 ] <= dq_i;
		else if (cnt == tCWL+1) 	curr_data[31:24] <= dq_i;
		else if (cnt == tCWL+2) 	curr_data[47:40] <= dq_i;
		else if (cnt == tCWL+3) 	curr_data[63:56] <= dq_i;

	always @(posedge ck_t)
		if (write_op && cnt == tCWL+4) data_write <= 1;
		else data_write <= 0;

	always @(posedge ck_t)
		if (data_write) mem[row][col] <= curr_data;

	assign dqs_t = read_op && (cnt >= tCL-1 && cnt <= tCL+4) ? ck_t : 'bZ;
	assign dqs_c = read_op && (cnt >= tCL-1 && cnt <= tCL+4) ? ck_c : 'bZ;
	assign dq_oe = read_op && (cnt >= tCL && cnt <= tCL+3);

	wire [63:0] read_data = mem[row][col];		
	always @* begin
		dq_o = 8'h01;
		if (read_op) begin
				 if (cnt == tCL+0) dq_o = dqs_t ? read_data[ 7:0 ] : dqs_c ? read_data[15:8 ]: 'bZ;
			else if (cnt == tCL+1) dq_o = dqs_t ? read_data[23:16] : dqs_c ? read_data[31:24]: 'bZ;
			else if (cnt == tCL+2) dq_o = dqs_t ? read_data[39:32] : dqs_c ? read_data[47:40]: 'bZ;
			else if (cnt == tCL+3) dq_o = dqs_t ? read_data[55:48] : dqs_c ? read_data[63:56]: 'bZ;
		end 
	end

	always @(posedge ck_t)
		if (opcode == MRS) begin
			if ({bg[0],ba} == 0) tCL = {a[6:4],a[2]} == 'b0001 ? 10: 9;
			else if ({bg[0],ba} == 2) tCWL = a[5:3] == 'b010 ? 11: 10;
		end
endmodule
