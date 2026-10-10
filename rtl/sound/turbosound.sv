//============================================================================
//  Turbosound-FM
// 
//  Copyright (C) 2018 Ilia Sharin
//  Copyright (C) 2018 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


module turbosound
(
	input         RESET,	    // Chip RESET (set all Registers to '0', active high)
	input         CLK,		 // Global clock
	input         CE,        // YM2203 Master Clock enable

	input         BDIR,	    // Bus Direction (0 - read , 1 - write)
	input         BC,		    // Bus control
	input   [7:0] DI,	       // Data In
	output  [7:0] DO,	       // Data Out

	output  [7:0] PSG_CH_A_0,
	output  [7:0] PSG_CH_B_0,
	output  [7:0] PSG_CH_C_0,
	output signed [15:0] OPN_0,
	output  [7:0] PSG_CH_A_1,
	output  [7:0] PSG_CH_B_1,
	output  [7:0] PSG_CH_C_1,
	output signed [15:0] OPN_1,

    input   [7:0]   IOA_0_in,
    input   [7:0]   IOB_0_in,
    output  [7:0]   IOA_0_out,
    output  [7:0]   IOB_0_out,
    output          IOA_0_oe,
    output          IOB_0_oe,

    input   [7:0]   IOA_1_in,
    input   [7:0]   IOB_1_in,
    output  [7:0]   IOA_1_out,
    output  [7:0]   IOB_1_out,
    output          IOA_1_oe,
    output          IOB_1_oe

);


reg       RESET_s;
reg       BDIR_s;
reg       BC_s;
reg [7:0] DI_s;

always_ff @(posedge CLK) begin
	reg       RESET_d;
	reg       BDIR_d;
	reg       BC_d;
	reg [7:0] DI_d;

	RESET_d <= RESET;
	BDIR_d <= BDIR;
	BC_d <= BC;
	DI_d <= DI;
	
	RESET_s <= RESET_d;
	BDIR_s <= BDIR_d;
	BC_s <= BC_d;
	DI_s <= DI_d;
end


// AY1 selected by default
reg ay_select = 1;
reg stat_sel  = 1;
reg fm_ena    = 0;
reg ym_wr     = 0;
reg [7:0] ym_di;

always_ff @(posedge CLK or posedge RESET_s) begin
	reg old_BDIR = 0;
	reg ym_acc = 0;

	if (RESET_s) begin
		ay_select <= 1;
		stat_sel  <= 1;
		fm_ena    <= 0;
		ym_acc    <= 0;
		ym_wr     <= 0;
		old_BDIR  <= 0;
	end
	else begin
		ym_wr <= 0;
		old_BDIR <= BDIR_s;
		if (~old_BDIR & BDIR_s) begin
			if(BC_s & &DI_s[7:3]) begin
				ay_select <=  DI_s[0];
				stat_sel  <=  DI_s[1];
				fm_ena    <= ~DI_s[2];
				ym_acc    <= 0;
			end
			else if(BC_s) begin
				ym_acc <= !DI_s[7:4] || fm_ena;
				ym_wr  <= !DI_s[7:4] || fm_ena;
			end
			else begin
				ym_wr <= ym_acc;
			end
			ym_di <= DI_s;
		end
	end
end

wire signed [15:0] opn_0;
wire  [7:0] DO_0;

jt03 ym2203_0
(
	.rst(RESET_s),
	.clk(CLK),
	.cen(CE),
	.din(ym_di),
	.addr((BDIR_s|ym_wr) ? ~BC_s : stat_sel),
	.cs_n(ay_select),
	.wr_n(~ym_wr),
	.dout(DO_0),

	.psg_A(PSG_CH_A_0),
	.psg_B(PSG_CH_B_0),
	.psg_C(PSG_CH_C_0),

	.fm_snd(opn_0),

	.IOA_in(IOA_0_in),
	.IOB_in(IOB_0_in),
	.IOA_out(IOA_0_out),
	.IOB_out(IOB_0_out),
	.IOA_oe(IOA_0_oe),
	.IOB_oe(IOB_0_oe)
);

wire signed [15:0] opn_1;
wire  [7:0] DO_1;

jt03 ym2203_1
(
	.rst(RESET_s),
	.clk(CLK),
	.cen(CE),
	.din(ym_di),
	.addr((BDIR_s|ym_wr) ? ~BC_s : stat_sel),
	.cs_n(~ay_select),
	.wr_n(~ym_wr),
	.dout(DO_1),

	.psg_A(PSG_CH_A_1),
	.psg_B(PSG_CH_B_1),
	.psg_C(PSG_CH_C_1),

	.fm_snd(opn_1),

	.IOA_in(IOA_1_in),
	.IOB_in(IOB_1_in),
	.IOA_out(IOA_1_out),
	.IOB_out(IOB_1_out),
	.IOA_oe(IOA_1_oe),
	.IOB_oe(IOB_1_oe)
);

assign DO = ay_select ? DO_1 : DO_0;
assign OPN_0 = fm_ena ? opn_0 : 16'sd0;
assign OPN_1 = fm_ena ? opn_1 : 16'sd0;

endmodule
