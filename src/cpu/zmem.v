// PentEvo project (c) NedoPC 2008-2009
//
// Z80 memory manager: routes ROM/RAM accesses, makes wait-states for 14MHz or stall condition, etc.
//
//
// clk    _/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\
//          |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// zclk     /```\___/```\___/```\___/```````\_______/```````\_______/```````````````\_______________/```````````````\_______________/`
//          |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// zpos     `\___/```\___/```\___/```\___________/```\___________/```\___________________________/```\___________________________/```\
//          |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// zneg     _/```\___/```\___/```\_______/```\___________/```\___________________/```\___________________________/```\________________

module zmem
(
	input         clk,
	input         c0, c1, c2, c3,
	input         zneg,     // strobes which show positive and negative edges of zclk
	input         zpos,

	// Z80
	input         rst,
	input  [15:0] za,
	output [ 7:0] zd_out,   // output to Z80 bus
	output        zd_ena,   // output to Z80 bus enable

	input         opfetch,
	input         opfetch_s,
	input         mreq,
	input         memrd,
	input         memwr,
	input         memwr_s,

	input  [ 1:0] turbo,     // 2'b00 - 3.5,
									 // 2'b01 - 7.0,
									 // 2'b1x - 14.0
	input   [3:0] cache_en,
	input   [3:0] memconf,
	input  [31:0] xt_page,

	output  [4:0] rompg,
	output        csrom,
	output        romoe_n,
	output        romwe_n,

	output        dos,
	output        dos_on,
	output        dos_off,
	output        vdos,
	output reg    pre_vdos,
	input         vdos_on,
	input         vdos_off,

	// DRAM
	output        cpu_req,
	output [20:0] cpu_addr,
	output        cpu_wrbsel,
	input  [15:0] cpu_rddata,
	input         cpu_next,
	input         cpu_strobe,
	input         cpu_latch,
	output        cpu_stall  // for zclock
);

// controls
wire rom128   = memconf[0];
wire w0_we    = memconf[1];
wire w0_map_n = memconf[2];
wire w0_ram   = memconf[3];

// pager
wire [1:0] win = za[15:14];
wire win0 = ~|win;
wire ramwr_en = !win0 || w0_we || vdos;
wire rom_n_ram = win0 && !w0_ram && !vdos;
wire [7:0] page = xtpage[win];

wire [7:0] xtpage[0:3];
assign xtpage[0] = vdos ? 8'hFF : {xt_page[7:2], w0_map_n ? xt_page[1:0] : {~dos, rom128}};
assign xtpage[1] = xt_page[15:8];
assign xtpage[2] = xt_page[23:16];
assign xtpage[3] = xt_page[31:24];

// ROM chip
assign csrom = rom_n_ram;
assign romoe_n = !memrd;
assign romwe_n = !(memwr && w0_we);
assign rompg = xtpage[0][4:0];

// RAM
assign zd_ena = !rom_n_ram && memrd;
wire ramreq = !rom_n_ram && ((memrd && !cache_hit_en) || (memwr && ramwr_en));

// DOS signal control
assign dos_on = win0 && opfetch_s && (za[13:8]==6'h3D) && rom128 && !w0_map_n;
assign dos_off = !win0 && opfetch_s && !vdos;

assign dos = (dos_on || dos_off) ^^ dos_r;    // to make dos appear 1 clock earlier than dos_r

reg dos_r;
always @(posedge clk) begin
	if (rst) dos_r <= 0;
	else if (dos_off) dos_r <= 0;
	else if (dos_on)  dos_r <= 1;
end

// VDOS signal control
// vdos turn on/off is delayed till next opfetch due to INIR that writes right after iord cycle
assign vdos = opfetch ? pre_vdos : vdos_r;  // vdos appears as soon as first opfetch

reg vdos_r;
always @(posedge clk) begin
	if (rst || vdos_off) begin
		pre_vdos <= 0;
		vdos_r <= 0;
	end
	else if (vdos_on) pre_vdos <= 1;
	else if (opfetch_s) vdos_r <= pre_vdos;
end

// address, data in and data out
assign cpu_wrbsel = za[0];
assign cpu_addr[20:0] = {page, za[13:1]};
wire [15:0] mem_d = cpu_latch ? cpu_rddata : cache_d;
assign zd_out = ~cpu_wrbsel ? mem_d[7:0] : mem_d[15:8];

// Z80 controls
assign cpu_req = turbo14 ? cpureq_14 : cpureq_357;
assign cpu_stall = turbo14 ? stall14 : stall357;
wire turbo14 = turbo[1];

// 7/3.5MHz support
wire cpureq_357 = ramreq && !ramreq_r;
wire stall357 = cpureq_357 && !cpu_next;

reg ramreq_r;
always @(posedge clk) if (c3 && !cpu_stall) ramreq_r <= ramreq;

// 14MHz support
// wait tables:
//
// M1 opcode fetch, dram_beg concurs with:
// c3:      +3
// c2:      +4
// c1:      +5
// c0:      +6
//
// memory read, dram_beg concurs with:
// c3:      +2
// c2:      +3
// c1:      +4
// c0:      +5
//
// memory write: no wait
//
// special case: if dram_beg pulses 1 when cpu_next is 0,
// unconditional wait has to be performed until cpu_next is 1, and
// then wait as if dram_beg would concur with c0

// memrd, opfetch - wait till c3 && cpu_next,
// memwr - wait till cpu_next

wire cpureq_14 = dram_beg || pending_cpu_req;
wire stall14 = stall14_ini || stall14_cyc || stall14_fin;

wire dram_beg = ramreq && !pre_ramreq_r && zneg;

reg pre_ramreq_r;
always @(posedge clk) if (zneg) pre_ramreq_r <= ramreq;

reg pending_cpu_req;
always @(posedge clk) begin
	if (rst) pending_cpu_req <= 0;
	else if (cpu_next && c3) pending_cpu_req <= 0;
	else if (dram_beg) pending_cpu_req <= 1;
end

wire stall14_ini = dram_beg && (!cpu_next || opfetch || memrd);  // no wait at all in write cycles, if next dram cycle is available
wire stall14_cyc = memrd ? stall14_cycrd : !cpu_next;

reg stall14_cycrd;
always @(posedge clk) begin
	if (rst) stall14_cycrd <= 0;
	else if (cpu_next && c3) stall14_cycrd <= 0;
	else if (dram_beg && (!c3 || !cpu_next) && (opfetch || memrd)) stall14_cycrd <= 1;
end

reg stall14_fin;
always @(posedge clk) begin
	if (rst) stall14_fin <= 0;
	else if (stall14_fin && ((opfetch && c1) || (memrd && c2))) stall14_fin <= 0;
	else if (cpu_next && c3 && cpu_req && (opfetch || memrd)) stall14_fin <= 1;
end

// cache
// wire cache_hit = (ch_addr[7:2] != 6'b011100) && (cpu_hi_addr == cache_a) && cache_v;  // debug for BM
wire cache_hit = (cpu_hi_addr == cache_a) && cache_v;  // asynchronous signal meaning that address requested by CPU is cached and valid
wire cache_hit_en = cache_hit && cache_en[win];
wire cache_inv = cache_hit && !rom_n_ram && memwr_s && ramwr_en;    // cache invalidation should be only performed if write happens to cached address

wire [12:0] cpu_hi_addr = {page[7:0], za[13:9]};
wire [12:0] cache_a;
wire [7:0] ch_addr = cpu_addr[7:0];

wire [15:0] cache_d;
wire cache_v;

dpram #(.DATAWIDTH(16), .ADDRWIDTH(8)) cache_data
(
	.clock(clk),
	.address_a(ch_addr),
	.data_a(cpu_rddata),
	.wren_a(cpu_strobe),
	.address_b(ch_addr),
	.q_b(cache_d)
);

dpram #(.DATAWIDTH(14), .ADDRWIDTH(8)) cache_addr
(
	.clock(clk),
	.address_a(ch_addr),
	.data_a({!cache_inv, cpu_hi_addr}),
	.wren_a(cpu_strobe || cache_inv),
	.address_b(ch_addr),
	.q_b({cache_v, cache_a})
);

endmodule
