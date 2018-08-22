
// This module generates all video raster signals


module video_sync
(
	// clocks
	input wire clk, f1, c0, c1, c3, pix_stb,

	// video parameters
	input wire [8:0] hpix_beg,
	input wire [8:0] hpix_end,
	input wire [8:0] vpix_beg,
	input wire [8:0] vpix_end,
	input wire [8:0] hpix_beg_ts,
	input wire [8:0] hpix_end_ts,
	input wire [8:0] vpix_beg_ts,
	input wire [8:0] vpix_end_ts,
	input wire [4:0] go_offs,
	input wire [1:0] x_offs,
	input wire [7:0] hint_beg,
	input wire [8:0] vint_beg,
	input wire [7:0] cstart,
	input wire [8:0] rstart,

	// video syncs
	output reg hsync,
	output reg vsync,

	// video controls
	input wire nogfx,
	output wire v_pf,
	output wire hpix,
	output wire vpix,
	output wire v_ts,
	output wire hvpix,
	output wire hvtspix,
	output wire tv_hblank,
	output wire tv_vblank,
	output wire frame_start,
	output wire line_start_s,
	output wire pix_start,
	output wire ts_start,
	output wire frame,
	output wire flash,

	// video counters
	output wire [8:0] ts_raddr,
	output reg  [8:0] lcount,
	output reg 	[7:0] cnt_col,
	output reg 	[8:0] cnt_row,
	output reg  	   cptr,
	output reg  [3:0] scnt,

	// DRAM
	input wire video_pre_next,
	output reg video_go,

	// ZX controls
	input wire y_offs_wr,
	output wire int_start
);

localparam HSYNC_BEG 	= 9'd11;
localparam HSYNC_END 	= 9'd43;
localparam HBLNK_BEG 	= 9'd00;
localparam HBLNK_END 	= 9'd88;
localparam HSYNCV_BEG 	= 9'd5;
localparam HSYNCV_END 	= 9'd31;
localparam HBLNKV_END 	= 9'd42;
localparam HPERIOD   	= 9'd448;

localparam VSYNC_BEG		= 9'd08;
localparam VSYNC_END 	= 9'd11;
localparam VBLNK_BEG 	= 9'd00;
localparam VBLNK_END 	= 9'd32;
localparam VPERIOD		= 9'd320;

// counters
reg [8:0] hcount = 0;
reg [8:0] vcount = 0;

// horizontal TV (7 MHz)
always @(posedge clk) if (c3) hcount <= line_start ? 9'b0 : hcount + 9'b1;

// vertical TV (15.625 kHz)
always @(posedge clk) if (line_start_s) vcount <= (vcount == (VPERIOD - 1)) ? 9'b0 : vcount + 9'b1;

// column address for DRAM
always @(posedge clk) begin
	if (line_start2) begin
		cnt_col <= cstart;
		cptr <= 1'b0;
	end
	else if (video_pre_next) begin
		cnt_col <= cnt_col + 8'b1;
		cptr <= ~cptr;
	end
end

// row address for DRAM
always @(posedge clk) begin if (c3)
	if (vis_start || (line_start && y_offs_wr_r)) cnt_row <=  rstart;
	else if (line_start && vpix) cnt_row <=  cnt_row + 9'b1;
end

// pixel counter
always @(posedge clk) if (pix_stb) scnt <= pix_start ? 4'b0 : scnt + 4'b1; // f1 or c3

// TS-line counter
assign ts_raddr = hcount - hpix_beg_ts;

always @(posedge clk) if (ts_start_coarse) lcount <= vcount - vpix_beg_ts + 9'b1;

// Y offset re-latch trigger
reg y_offs_wr_r;
always @(posedge clk) begin
	if (y_offs_wr) y_offs_wr_r <= 1'b1;
	else if (line_start_s) y_offs_wr_r <= 1'b0;
end

// FLASH generator
reg [4:0] flash_ctr;
assign frame = flash_ctr[0];
assign flash = flash_ctr[4];
always @(posedge clk) begin
	if (frame_start && c3) begin
		flash_ctr <= flash_ctr + 5'b1;
	end
end

// sync strobes
wire hs = (hcount >= HSYNC_BEG) && (hcount < HSYNC_END);
wire vs = (vcount >= VSYNC_BEG) && (vcount < VSYNC_END);

assign tv_hblank = (hcount > HBLNK_BEG) && (hcount <= HBLNK_END);
assign tv_vblank = (vcount >= VBLNK_BEG) && (vcount < VBLNK_END);

assign hvpix = hpix && vpix;
	
assign hpix = (hcount >= hpix_beg) && (hcount < hpix_end);
	
assign vpix = (vcount >= vpix_beg) && (vcount < vpix_end);

assign hvtspix = htspix && vtspix;
wire htspix = (hcount >= hpix_beg_ts) && (hcount < hpix_end_ts);
wire vtspix = (vcount >= vpix_beg_ts) && (vcount < vpix_end_ts);

assign v_ts = (vcount >= (vpix_beg_ts - 1))  && (vcount < (vpix_end_ts - 1));  // vertical TS window
assign v_pf = (vcount >= (vpix_beg_ts - 17)) && (vcount < (vpix_end_ts - 9));  // vertical tilemap prefetch window

always @(posedge clk) video_go <= (hcount >= (hpix_beg - go_offs - x_offs)) && (hcount < (hpix_end - go_offs - x_offs + 4)) && vpix && !nogfx;

wire line_start = hcount == (HPERIOD - 1);
assign line_start_s = line_start && c3;
wire line_start2 = hcount == (HSYNC_END - 1);
assign frame_start = line_start && (vcount == (VPERIOD - 1));
wire vis_start = line_start && (vcount == (VBLNK_END - 1));
assign pix_start = hcount == (hpix_beg - x_offs - 1);
wire ts_start_coarse = hcount == (hpix_beg_ts - 1);
assign ts_start = c3 && ts_start_coarse;
assign int_start = (hcount == {hint_beg, 1'b0}) && (vcount == vint_beg) && c0;

always @(posedge clk) begin
	hsync <= hs;
	vsync <= vs;
end

endmodule
