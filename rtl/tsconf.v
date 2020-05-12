
/* ----------------------------------------------------------------[02.11.2014]
	u16-TSConf Version 0.2.9
	DEVBOARD ReVerSE-U16 By MVV
	----------------------------------------------------------------------------
	V0.1.0	27.07.2014	первая версия
	V0.2.0	31.07.2014	добавлен транслятор PS/2, HDMI
	V0.2.1	03.08.2014	добавлен Delta-Sigma DAC, I2C
	V0.2.3	11.08.2014	добавлен enc424j600
	V0.2.4	24.08.2014	добавлена поддержка IDE Video DAC (zports.v, video_out.v)
	V0.2.5	07.09.2014	добавлен порт #0001=key_scan, изменения в keyboard.vhd
	V0.2.6	09.09.2014	исправлен вывод палитры в (lut.vhd)
	V0.2.7	13.09.2014	дрожание мультиколора на tv80s, заменил на t80s
	V0.2.8	19.10.2014	инвентирован CLK в модулях video_tmbuf, video_sfile и добавлены регистры на выходе
	V0.2.9	02.11.2014	замена t80s, исправления в zint.v, zports.v, delta-sigma (приводит к намагничиванию динамиков)
	WXEDA	10.03.2015  порт на девборду WXEDA
	
	http://tslabs.info/forum/viewtopic.php?f=31&t=401
	http://zx-pk.ru/showthread.php?t=23528
	
	Copyright (c) 2014 MVV, TS-Labs, dsp, waybester, palsw
	
	All rights reserved
	
	Redistribution and use in source and synthezised forms, with or without
	modification, are permitted provided that the following conditions are met:
	
	* Redistributions of source code must retain the above copyright notice,
	this list of conditions and the following disclaimer.
	
	* Redistributions in synthesized form must reproduce the above copyright
	notice, this list of conditions and the following disclaimer in the
	documentation and/or other materials provided with the distribution.
	
	* Neither the name of the author nor the names of other contributors may
	be used to endorse or promote products derived from this software without
	specific prior written agreement from the author.
	
	* License is granted for non-commercial use only.  A fee may not be charged
	for redistributions as source code or in synthesized/hardware form without 
	specific prior written agreement from the author.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
	PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.
*/

module tsconf
(
	// Clocks
	input         clk,
	input         ce,

	// SDRAM (32MB 16x16bit)
	inout  [15:0] SDRAM_DQ,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
	output        SDRAM_CKE,
	output        SDRAM_CLK,

	// VGA
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_HBLANK,
	output        VGA_VBLANK,
	output        VGA_CEPIX,

	// SD/MMC Memory Card
	input         SD_SO,
	output        SD_SI,
	output        SD_CLK,
	output        SD_CS_N,

	// General Sound
	output [20:0] GS_ADDR,
	output  [7:0] GS_DI,
	input   [7:0] GS_DO,
	output        GS_RD,
	output        GS_WR,
	input         GS_WAIT,

	// Audio
	output [15:0] SOUND_L,
	output [15:0] SOUND_R,

	// Misc. I/O
	input         COLD_RESET,
	input         WARM_RESET,
	output        RESET_OUT,
	input  [64:0] RTC,
	input  [31:0] CMOSCfg,
	input         OUT0,

	// PS/2 Keyboard
	input  [10:0] PS2_KEY,
	input  [24:0] PS2_MOUSE,
	input   [5:0] joystick,

	input  [15:0] loader_addr,
	input   [7:0] loader_data,
	input         loader_wr
);


// CPU0
wire [15:0] cpu_a_bus;
wire [7:0]  cpu_do_bus;
wire [7:0]  cpu_di_bus;
wire        cpu_mreq_n;
wire        cpu_iorq_n;
wire        cpu_wr_n;
wire        cpu_rd_n;
wire        cpu_int_n_TS;
wire        cpu_m1_n;
wire        cpu_rfsh_n;
wire [1:0]  turbo;
wire [7:0]  im2vect;

// zsignal
wire        cpu_stall;		// zmem -> zclock
wire        cpu_req;		// zmem -> arbiter
wire        cpu_wrbsel;		// zmem -> arbiter
wire        cpu_next;		// arbiter -> zmem
wire        cpu_current;		// arbiter -> zmem
wire        cpu_strobe;		// arbiter -> zmem
wire        cpu_latch;		// arbiter -> zmem
wire [23:0] cpu_addr;
wire [20:0] cpu_addr_20;
wire        csrom;
wire        curr_cpu;

// SDRAM
wire [7:0]  sdr_do_bus;
wire [15:0] sdr_do_bus_16;
wire [15:0] sdr_do_bus_16cpu;
wire        sdr_wr;
wire        sdr_rd;
wire        req;
wire        rnw;
wire [23:0] dram_addr;
wire [1:0]  dram_bsel;
wire [15:0] dram_wrdata;
wire        dram_req;
wire        dram_rnw;
wire        dos;

wire        vdos;
wire        pre_vdos;
wire        vdos_off;
wire        vdos_on;
wire        dos_on;
wire        m1;
wire        rd;
wire        wr;
wire        iorq;
wire        mreq;
wire        rdwr;
wire        iord;
wire        iowr;
wire        iorw;
wire        memrd;
wire        memwr;
wire        opfetch;
wire        intack;
wire        iorq_s;
wire        iord_s;
wire        iowr_s;
wire        iorw_s;
wire        memwr_s;
wire        opfetch_s;
wire        regs_we;

// zports OUT
wire [7:0]  dout_ports;
wire        ena_ports;
wire [31:0] xt_page;
wire [4:0]  fmaddr;
wire [7:0]  sysconf;
wire [7:0]  memconf;
wire [7:0]  intmask;
wire [8:0]  dmaport_wr;
wire        go_arbiter;
wire [3:0]  cacheconf;

// z80
wire [15:0] zmd;
wire [7:0]  zma;
wire        cram_we;
wire        sfile_we;
wire        zborder_wr;
wire        border_wr;
wire        zvpage_wr;
wire        vpage_wr;
wire        vconf_wr;
wire        gx_offsl_wr;
wire        gx_offsh_wr;
wire        gy_offsl_wr;
wire        gy_offsh_wr;
wire        t0x_offsl_wr;
wire        t0x_offsh_wr;
wire        t0y_offsl_wr;
wire        t0y_offsh_wr;
wire        t1x_offsl_wr;
wire        t1x_offsh_wr;
wire        t1y_offsl_wr;
wire        t1y_offsh_wr;
wire        tsconf_wr;
wire        palsel_wr;
wire        tmpage_wr;
wire        t0gpage_wr;
wire        t1gpage_wr;
wire        sgpage_wr;
wire        hint_beg_wr;
wire        vint_begl_wr;
wire        vint_begh_wr;

// ZX controls
wire        res;
wire        int_start_frm;
wire        int_start_lin;

// DRAM interface
wire [20:0] video_addr;
wire [4:0]  video_bw;
wire        video_go;
wire        video_next;
wire        video_pre_next;
wire        next_video;
wire        video_strobe;

// TS
wire [20:0] ts_addr;
wire        ts_req;

// IN
wire        ts_pre_next;
wire        ts_next;

// TM
wire [20:0] tm_addr;
wire        tm_req;
wire        tm_next;

// DMA
wire        dma_rnw;
wire        dma_req;
wire [15:0] dma_wrdata;
wire [20:0] dma_addr;
wire        dma_next;
wire        dma_act;
wire        dma_cram_we;
wire        dma_sfile_we;

// zmap
wire [15:0] dma_data;
wire [7:0]  dma_wraddr;
wire        int_start_dma;
// SPI
wire        spi_start;
wire        dma_spi_req;
wire [7:0]  dma_spi_din;
wire        cpu_spi_req;
wire [7:0]  cpu_spi_din;
wire [7:0]  spi_dout;

wire [7:0]  mouse_do;

   
// clock
wire clk_28mhz = clk & ce;

wire f0,f1;
wire h0,h1;
wire c0,c1,c2,c3;

clock TS01
(
	.clk(clk_28mhz),
	.f0(f0),
	.f1(f1),
	.h0(h0),
	.h1(h1),
	.c0(c0),
	.c1(c1),
	.c2(c2),
	.c3(c3)
);

wire zclk;
wire zpos, zneg;
zclock TS02
(
	.clk(clk_28mhz),
	.c0(c0),
	.c2(c2),
	.f0(f0),
	.f1(f1),
	.zclk_out(zclk),
	.zpos(zpos),
	.zneg(zneg),
	.iorq_s(iorq_s),
	.dos_on(dos_on),
	.vdos_off(vdos_off),
	.cpu_stall(cpu_stall),
	.ide_stall(0),
	.external_port(0),
	.turbo(turbo)
);

reg zclk_r;
always @(posedge clk) zclk_r <= zclk;

T80s CPU
(
	.RESET_n(~reset),
	.CLK(clk),
	.CEN(~zclk_r & zclk),
	.INT_n(cpu_int_n_TS),
	.M1_n(cpu_m1_n),
	.MREQ_n(cpu_mreq_n),
	.IORQ_n(cpu_iorq_n),
	.RD_n(cpu_rd_n),
	.WR_n(cpu_wr_n),
	.RFSH_n(cpu_rfsh_n),
	.OUT0(OUT0),
	.A(cpu_a_bus),
	.DI(cpu_di_bus),
	.DO(cpu_do_bus)
);

zsignals TS04
(
	.clk(clk_28mhz),
	.iorq_n(cpu_iorq_n),
	.mreq_n(cpu_mreq_n),
	.m1_n(cpu_m1_n),
	.rfsh_n(cpu_rfsh_n),
	.rd_n(cpu_rd_n),
	.wr_n(cpu_wr_n),
	.rd(rd),
	.wr(wr),
	.iorq(iorq),
	.mreq(mreq),
	.rdwr(rdwr),
	.iord(iord),
	.iowr(iowr),
	.iorw(iorw),
	.memrd(memrd),
	.memwr(memwr),
	.opfetch(opfetch),
	.intack(intack),
	.iorq_s(iorq_s),
	.iord_s(iord_s),
	.iowr_s(iowr_s),
	.iorw_s(iorw_s),
	.memwr_s(memwr_s),
	.opfetch_s(opfetch_s)
);

zports TS05
(
	.clk(clk_28mhz),
	.din(cpu_do_bus),
	.dout(dout_ports),
	.dataout(ena_ports),
	.a(cpu_a_bus),
	.rst(reset),
	.opfetch(opfetch),		// from zsignals
	.rd(rd),
	.wr(wr),
	.rdwr(rdwr),
	.iorq(iorq),
	.iorq_s(iorq_s),
	.iord(iord),
	.iord_s(iord_s),
	.iowr(iowr),
	.iowr_s(iowr_s),
	.iordwr(iorw),
	.iordwr_s(iorw_s),
	.zborder_wr(zborder_wr),
	.border_wr(border_wr),
	.zvpage_wr(zvpage_wr),
	.vpage_wr(vpage_wr),
	.vconf_wr(vconf_wr),
	.gx_offsl_wr(gx_offsl_wr),
	.gx_offsh_wr(gx_offsh_wr),
	.gy_offsl_wr(gy_offsl_wr),
	.gy_offsh_wr(gy_offsh_wr),
	.t0x_offsl_wr(t0x_offsl_wr),
	.t0x_offsh_wr(t0x_offsh_wr),
	.t0y_offsl_wr(t0y_offsl_wr),
	.t0y_offsh_wr(t0y_offsh_wr),
	.t1x_offsl_wr(t1x_offsl_wr),
	.t1x_offsh_wr(t1x_offsh_wr),
	.t1y_offsl_wr(t1y_offsl_wr),
	.t1y_offsh_wr(t1y_offsh_wr),
	.tsconf_wr(tsconf_wr),
	.palsel_wr(palsel_wr),
	.tmpage_wr(tmpage_wr),
	.t0gpage_wr(t0gpage_wr),
	.t1gpage_wr(t1gpage_wr),
	.sgpage_wr(sgpage_wr),
	.hint_beg_wr(hint_beg_wr),
	.vint_begl_wr(vint_begl_wr),
	.vint_begh_wr(vint_begh_wr),
	.xt_page(xt_page),
	.fmaddr(fmaddr),
	.regs_we(regs_we),
	.sysconf(sysconf),
	.memconf(memconf),
	.cacheconf(cacheconf),
	.intmask(intmask),
	.dmaport_wr(dmaport_wr),		// dmaport_wr
	.dma_act(dma_act),		// from DMA (status of DMA) 
	.dos(dos),
	.vdos(vdos),
	.vdos_on(vdos_on),
	.vdos_off(vdos_off),
	.tape_read(1),
	.keys_in(kb_do_bus),		// keys (port FE)
	.mus_in(mouse_do),		// mouse (xxDF)
	.kj_in(joystick),
	.vg_intrq(0),
	.vg_drq(0),		// from vg93 module - drq + irq read
	.sdcs_n(SD_CS_N),		// to SD card
	.sd_start(cpu_spi_req),		// to SPI
	.sd_datain(cpu_spi_din),		// to SPI(7 downto 0);
	.sd_dataout(spi_dout),		// from SPI(7 downto 0); 
	.wait_addr(wait_addr),
	.wait_start_gluclock(wait_start_gluclock),
	.wait_read(mc146818a_do_bus)
);

zmem TS06
(
	.clk(clk_28mhz),
	.c0(c0),
	.c1(c1),
	.c2(c2),
	.c3(c3),
	.zpos(zpos),
	.zneg(zneg),
	.rst(reset),		// PLL locked
	.za(cpu_a_bus),		// from CPU
	.zd_out(sdr_do_bus),		// output to Z80 bus 8bit ==>
	.zd_ena(),		// output to Z80 bus enable
	.opfetch(opfetch),		// from zsignals
	.opfetch_s(opfetch_s),		// from zsignals
	.mreq(mreq),		// from zsignals
	.memrd(memrd),		// from zsignals
	.memwr(memwr),		// from zsignals
	.memwr_s(memwr_s),		// from zsignals 
	.turbo(turbo),
	.cache_en(cacheconf),		// from zport
	.memconf(memconf[3:0]),
	.xt_page(xt_page),
	.csrom(csrom),
	.dos(dos),
	.dos_on(dos_on),
	.vdos(vdos),
	.pre_vdos(pre_vdos),
	.vdos_on(vdos_on),
	.vdos_off(vdos_off),
	.cpu_req(cpu_req),
	.cpu_addr(cpu_addr_20),
	.cpu_wrbsel(cpu_wrbsel),		// for 16bit data
	.cpu_rddata(sdr_do_bus_16cpu),
	.cpu_next(cpu_next),
	.cpu_strobe(cpu_strobe),		// from ARBITER ACTIVE=HI 	
	.cpu_latch(cpu_latch),
	.cpu_stall(cpu_stall)		// for Zclock if HI-> STALL (ZCLK)
);

arbiter TS07
(
	.clk(clk_28mhz),
	.c0(c0),
	.c1(c1),
	.c2(c2),
	.c3(c3),
	.dram_addr(dram_addr),
	.dram_req(dram_req),
	.dram_rnw(dram_rnw),
	.dram_bsel(dram_bsel),
	.dram_wrdata(dram_wrdata),		// data to be written
	.video_addr(video_addr),		// during access block, only when video_strobe==1
	.go(go_arbiter),		// start video access blocks
	.video_bw(video_bw),		// ZX="11001", [4:3] -total cycles: 11 = 8 / 01 = 4 / 00 = 2
	.video_pre_next(video_pre_next),
	.video_next(video_next),		// (c2) at this signal video_addr may be changed; it is one clock leading the video_strobe
	.video_strobe(video_strobe),		// (c3) one-cycle strobe meaning that video_data is available
	.next_vid(next_video),		// used for TM prefetch
	.cpu_addr(cpu_addr_20),
	.cpu_wrdata(cpu_do_bus),
	.cpu_req(cpu_req),
	.cpu_rnw(rd | csrom),
	.cpu_wrbsel(cpu_wrbsel),
	.cpu_next(cpu_next),		// next cycle is allowed to be used by CPU
	.cpu_strobe(cpu_strobe),		// c2 strobe
	.cpu_latch(cpu_latch),		// c2-c3 strobe
	.curr_cpu_o(curr_cpu),
	.dma_addr(dma_addr),
	.dma_wrdata(dma_wrdata),
	.dma_req(dma_req),
	.dma_rnw(dma_rnw),
	.dma_next(dma_next),
	.ts_addr(ts_addr),
	.ts_req(ts_req),
	.ts_pre_next(ts_pre_next),
	.ts_next(ts_next),
	.tm_addr(tm_addr),
	.tm_req(tm_req),
	.tm_next(tm_next)
);

video_top TS08
(
	.clk(clk_28mhz),
	.f0(f0),
	.f1(f1),
	.h0(h0),
	.h1(h1),
	.c0(c0),
	.c1(c1),
	.c2(c2),
	.c3(c3),
	.vred(VGA_R),
	.vgrn(VGA_G),
	.vblu(VGA_B),
	.hsync(VGA_HS),
	.vsync(VGA_VS),
	.hblank(VGA_HBLANK),
	.vblank(VGA_VBLANK),
	.pix_stb(VGA_CEPIX),
	.d(cpu_do_bus),
	.zmd(zmd),
	.zma(zma),
	.cram_we(cram_we),
	.sfile_we(sfile_we),
	.zborder_wr(zborder_wr),
	.border_wr(border_wr),
	.zvpage_wr(zvpage_wr),
	.vpage_wr(vpage_wr),
	.vconf_wr(vconf_wr),
	.gx_offsl_wr(gx_offsl_wr),
	.gx_offsh_wr(gx_offsh_wr),
	.gy_offsl_wr(gy_offsl_wr),
	.gy_offsh_wr(gy_offsh_wr),
	.t0x_offsl_wr(t0x_offsl_wr),
	.t0x_offsh_wr(t0x_offsh_wr),
	.t0y_offsl_wr(t0y_offsl_wr),
	.t0y_offsh_wr(t0y_offsh_wr),
	.t1x_offsl_wr(t1x_offsl_wr),
	.t1x_offsh_wr(t1x_offsh_wr),
	.t1y_offsl_wr(t1y_offsl_wr),
	.t1y_offsh_wr(t1y_offsh_wr),
	.tsconf_wr(tsconf_wr),
	.palsel_wr(palsel_wr),
	.tmpage_wr(tmpage_wr),
	.t0gpage_wr(t0gpage_wr),
	.t1gpage_wr(t1gpage_wr),
	.sgpage_wr(sgpage_wr),
	.hint_beg_wr(hint_beg_wr),
	.vint_begl_wr(vint_begl_wr),
	.vint_begh_wr(vint_begh_wr),
	.res(reset),
	.int_start(int_start_frm),
	.line_start_s(int_start_lin),
	.video_addr(video_addr),
	.video_bw(video_bw),
	.video_go(go_arbiter),
	.dram_rdata(sdr_do_bus_16),		// raw, should be latched by c2 (video_next)
	.video_next(video_next),
	.video_pre_next(video_pre_next),
	.next_video(next_video),
	.video_strobe(video_strobe),
	.ts_addr(ts_addr),
	.ts_req(ts_req),
	.ts_pre_next(ts_pre_next),
	.ts_next(ts_next),
	.tm_addr(tm_addr),
	.tm_req(tm_req),
	.tm_next(tm_next)
);

dma TS09
(
	.clk(clk_28mhz),
	.c2(c2),
	.reset(reset),
	.dmaport_wr(dmaport_wr),
	.dma_act(dma_act),
	.data(dma_data),
	.wraddr(dma_wraddr),
	.int_start(int_start_dma),
	.zdata(cpu_do_bus),
	.dram_addr(dma_addr),
	.dram_rddata(sdr_do_bus_16),
	.dram_wrdata(dma_wrdata),
	.dram_req(dma_req),
	.dram_rnw(dma_rnw),
	.dram_next(dma_next),
	.spi_rddata(spi_dout),
	.spi_wrdata(dma_spi_din),
	.spi_req(dma_spi_req),
	.spi_stb(spi_start),
	.ide_in(0),
	.ide_stb(0),
	.cram_we(dma_cram_we),
	.sfile_we(dma_sfile_we)
);

zmaps TS10
(
	.clk(clk_28mhz),
	.memwr_s(memwr_s),
	.a(cpu_a_bus),
	.d(cpu_do_bus),
	.fmaddr(fmaddr),
	.zmd(zmd),
	.zma(zma),
	.dma_data(dma_data),
	.dma_wraddr(dma_wraddr),
	.dma_cram_we(dma_cram_we),
	.dma_sfile_we(dma_sfile_we),
	.cram_we(cram_we),
	.sfile_we(sfile_we),
	.regs_we(regs_we)
);

spi TS11
(
	.clk(clk_28mhz),
	.sck(SD_CLK),
	.sdo(SD_SI),
	.sdi(SD_SO),
	.dma_req(dma_spi_req),
	.dma_din(dma_spi_din),
	.cpu_req(cpu_spi_req),
	.cpu_din(cpu_spi_din),
	.start(spi_start),
	.dout(spi_dout)
);

zint TS13
(
	.clk(clk_28mhz),
	.zpos(zpos),
	.res(reset),
	.int_start_frm(int_start_frm),		//< N1 VIDEO
	.int_start_lin(int_start_lin),		//< N2 VIDEO
	.int_start_dma(int_start_dma),		//< N3 DMA
	.vdos(pre_vdos),		// vdos,--pre_vdos
	.intack(intack),		//< zsignals  === (intack ? im2vect : 8'hFF)));
	.intmask(intmask),		//< ZPORT (7 downto 0);
	.im2vect(im2vect),		//> CPU Din (2 downto 0); 	
	.int_n(cpu_int_n_TS)
);
   
// BIOS
wire [7:0] bios_do_bus;
dpram #(.ADDRWIDTH(16), .MEM_INIT_FILE("rtl/tsbios.mif")) BIOS
(
	.clock(clk),
	.address_a({cpu_addr_20[14:0],cpu_wrbsel}),
	.q_a(bios_do_bus),
	
	.address_b(loader_addr),
	.data_b(loader_data),
	.wren_b(loader_wr)
);

// SDRAM Controller
sdram SE4
(
	.clk(clk),
	.cyc(ce&c3),

	.curr_cpu(curr_cpu),
	.bsel(dram_bsel),
	.A(dram_addr),
	.DI(dram_wrdata),
	.DO(sdr_do_bus_16),
	.DO_cpu(sdr_do_bus_16cpu),
	.REQ(dram_req),
	.RNW(dram_rnw),

	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_A(SDRAM_A),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_CLK(SDRAM_CLK)
);


// PS/2 Keyboard
wire [4:0] kb_do_bus;
wire       key_reset;
wire [7:0] key_scancode;

keyboard SE5
(
	.clk(clk_28mhz),
	.reset(COLD_RESET | WARM_RESET),
	.a(cpu_a_bus[15:8]),
	.keyb(kb_do_bus),
	.KEY_RESET(key_reset),
	.scancode(key_scancode),
	.ps2_key(PS2_KEY)
);

kempston_mouse KM
(
	.clk_sys(clk_28mhz),
	.reset(reset),
	.ps2_mouse(PS2_MOUSE),
	.addr(cpu_a_bus[10:8]),
	.dout(mouse_do)
);

// MC146818A,RTC
wire [7:0] wait_addr;
wire       wait_start_gluclock;
wire [7:0] mc146818a_do_bus;

reg ena_0_4375mhz;
always @(posedge clk_28mhz) begin
	reg [5:0] div;
	div <= div + 1'd1;
	ena_0_4375mhz <= !div; //28MHz/64
end

mc146818a SE9
(
	.RESET(reset),
	.CLK(clk_28mhz),
	.ENA(ena_0_4375mhz),
	.CS(1),
	.KEYSCANCODE(key_scancode),
	.RTC(RTC),
	.CMOSCfg(CMOSCfg),
	.WR(wait_start_gluclock & ~cpu_wr_n),
	.A(wait_addr),
	.DI(cpu_do_bus),
	.DO(mc146818a_do_bus)
);


// Soundrive
wire [7:0]  covox_a;
wire [7:0]  covox_b;
wire [7:0]  covox_c;
wire [7:0]  covox_d;

soundrive SE10
(
	.reset(reset),
	.clk(clk_28mhz),
	.cs(1),
	.wr_n(cpu_wr_n),
	.a(cpu_a_bus[7:0]),
	.di(cpu_do_bus),
	.iorq_n(cpu_iorq_n),
	.dos(dos),
	.outa(covox_a),
	.outb(covox_b),
	.outc(covox_c),
	.outd(covox_d)
);

// Turbosound FM
reg ce_ym;
always @(posedge clk_28mhz) begin
	reg [2:0] div;
	
	div <= div + 1'd1;
	ce_ym <= !div;
end

wire ts_enable = ~cpu_iorq_n & cpu_a_bus[0] & cpu_a_bus[15] & ~cpu_a_bus[1];
wire ts_we     = ts_enable & ~cpu_wr_n;

wire [11:0] ts_l, ts_r;
wire  [7:0] ts_do;

turbosound SE12
(
	.RESET(reset),

	.CLK(clk_28mhz),
	.CE(ce_ym),
	.BDIR(ts_we),
	.BC(cpu_a_bus[14]),
	.DI(cpu_do_bus),
	.DO(ts_do),
	.CHANNEL_L(ts_l),
	.CHANNEL_R(ts_r)
);


// General Sound
wire [14:0] gs_l;
wire [14:0] gs_r;
wire [7:0]  gs_do_bus;
wire        gs_sel = ~cpu_iorq_n & cpu_m1_n & (cpu_a_bus[7:4] == 'hB && cpu_a_bus[2:0] == 'h3);

gs #("rtl/sound/gs105b.mif") U15
(
	.RESET(reset),
	.CLK(clk),
	.CE(ce),
	
	.A(cpu_a_bus[3]),
	.DI(cpu_do_bus),
	.DO(gs_do_bus),
	.CS_n(cpu_iorq_n | ~gs_sel),
	.WR_n(cpu_wr_n),
	.RD_n(cpu_rd_n),
	
	.MEM_ADDR(GS_ADDR),
	.MEM_DI(GS_DI),
	.MEM_DO(GS_DO),
	.MEM_RD(GS_RD),
	.MEM_WR(GS_WR),
	.MEM_WAIT(GS_WAIT),
	
	.OUTL(gs_l),
	.OUTR(gs_r)
);


// SAA1099
wire [7:0]  saa_out_l;
wire [7:0]  saa_out_r;
wire        saa_wr_n = ~cpu_iorq_n && ~cpu_wr_n && cpu_a_bus[7:0] == 8'hFF && ~dos;

reg ce_saa;
always @(posedge clk_28mhz) begin
	reg [2:0] div;

	div <= div + 1'd1;
	if(div == 6) div <= 0;

	ce_saa <= (div == 0 || div == 3);
end

saa1099 U16
(
	.clk_sys(clk_28mhz),
	.ce(ce_saa),
	.rst_n(~reset),
	.cs_n(0),
	.a0(cpu_a_bus[8]),		// 0=data, 1=address
	.wr_n(saa_wr_n),
	.din(cpu_do_bus),
	.out_l(saa_out_l),
	.out_r(saa_out_r)
);

wire [11:0] audio_l = ts_l + {gs_l[14], gs_l[14:4]} + {2'b00, covox_a, 2'b00} + {2'b00, covox_b, 2'b00} + {1'b0, saa_out_l, 3'b000} + {3'b000, port_xxfe_reg[4], 8'b00000000};
wire [11:0] audio_r = ts_r + {gs_r[14], gs_r[14:4]} + {2'b00, covox_c, 2'b00} + {2'b00, covox_d, 2'b00} + {1'b0, saa_out_r, 3'b000} + {3'b000, port_xxfe_reg[4], 8'b00000000};

compressor compressor
(
	clk_28mhz,
	audio_l, audio_r,
	SOUND_L, SOUND_R
);


//-----------------------------------------------------------------------------
// Global
//-----------------------------------------------------------------------------
wire reset = COLD_RESET | WARM_RESET | key_reset;
assign RESET_OUT = reset;

// CPU interface
assign cpu_di_bus = 
		(csrom && ~cpu_mreq_n && ~cpu_rd_n) 						?	bios_do_bus			:	// BIOS
		(~cpu_mreq_n && ~cpu_rd_n)										?	sdr_do_bus			:	// SDRAM
		(intack)																?	im2vect 				:
		(gs_sel && ~cpu_rd_n)											?	gs_do_bus			:	// General Sound
		(ts_enable && ~cpu_rd_n)										?	ts_do					:	// TurboSound
		(cpu_a_bus == 16'h0001 && ~cpu_iorq_n && ~cpu_rd_n)	?	key_scancode		:
		(ena_ports)															?	dout_ports			:
																					8'b11111111;
// TURBO
assign turbo = sysconf[1:0];

reg [7:0] port_xxfe_reg;
always @(posedge clk_28mhz) begin
	if (reset) port_xxfe_reg <= 0;
	else if (~cpu_iorq_n && ~cpu_wr_n && cpu_a_bus[7:0] == 8'hFE) port_xxfe_reg <= cpu_do_bus;
end

endmodule
