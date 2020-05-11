
// This module generates video for DAC
// (c)2015 TSL

module video_out
(
	// clocks
	input wire clk, c3,

	// video controls
	input wire tv_blank,
	input wire [1:0] plex_sel_in,

	// mode controls
	input wire tv_hires,
	input wire [3:0] palsel,

	// Z80 pins
	input  wire [15:0] cram_data_in,
	input  wire [7:0] cram_addr_in,
	input  wire cram_we,

	// video data
	input  wire [7:0] vplex_in,
	output wire [7:0] vred,
	output wire [7:0] vgrn,
	output wire [7:0] vblu,
	output wire vdac_mode
);


reg [7:0] vplex;
always @(posedge clk) if (c3) vplex <= vplex_in;

wire [7:0] vdata = tv_hires ? {palsel, plex_sel_in[1] ? vplex[3:0] : vplex[7:4]} : vplex;


// CRAM
wire [15:0] vpixel;
dpram #(.DATAWIDTH(16), .ADDRWIDTH(8), .MEM_INIT_FILE("rtl/video/video_cram.mif")) video_cram
(
	.clock    (clk),
	.address_a(cram_addr_in),
	.data_a   (cram_data_in),
	.wren_a   (cram_we),
	.address_b(vdata),
	.q_b      (vpixel)
);

reg blank;
always @(posedge clk) blank <= tv_blank;

wire [14:0] vpix = blank ? 15'b0 : vpixel[14:0];

assign vred = {vpix[14:10], vpix[14:12]};
assign vgrn = {vpix[ 9: 5], vpix[ 9: 7]};
assign vblu = {vpix[ 4: 0], vpix[ 4: 2]};
assign vdac_mode = vpixel[15];

endmodule
