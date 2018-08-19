
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

module tsconf(
   // Clocks
   input         clk_84mhz,
   input         clk_28mhz,
   
   // SDRAM (32MB 16x16bit)
   inout  [15:0] SDRAM_DQ,
   output [12:0] SDRAM_A,
   output  [1:0] SDRAM_BA,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_WE_N,
   output        SDRAM_CAS_N,
   output        SDRAM_RAS_N,
   output        SDRAM_CKE,
   output        SDRAM_CS_N,
   
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
   input         GS_ENA,
   output [21:0] GS_ADDR,
   output  [7:0] GS_DI,
   input   [7:0] GS_DO,
   output        GS_RD,
   output        GS_WR,
   input         GS_WAIT,
   
   // Audio
   output [15:0] SOUND_L,
   output [15:0] SOUND_R,
   
   // External I/O
   input         COLD_RESET,
   input         WARM_RESET,
   output        RESET_OUT,
   input  [64:0] RTC,
   input  [31:0] CMOSCfg,
   
   // PS/2 Keyboard
   input  [10:0] PS2_KEY,
   input  [24:0] PS2_MOUSE,
   input   [5:0] joystick
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
wire [2:0]  cpu_addr_ext;
wire        csvrom;
wire        curr_cpu;
// Memory
wire [7:0]  rom_do_bus;
wire [3:0]  cacheconf;
// SDRAM
wire [7:0]  sdr_do_bus;
wire [15:0] sdr_do_bus_16;
wire [15:0] sdr2cpu_do_bus_16;
wire        sdr_wr;
wire        sdr_rd;
wire        req;
wire        rnw;
wire [23:0] dram_addr;
wire [1:0]  dram_bsel;
wire [15:0] dram_wrdata;
wire        dram_req;
wire        dram_rnw;
// Port
reg [7:0]   port_xxfe_reg;
reg [7:0]   port_xx01_reg;
reg         ena_1_75mhz;
reg [5:0]   ena_cnt;
// System
wire        reset;
//signal key_reset	: std_logic;
reg         loader;
wire        zports_loader;
wire        dos;
//signal xtpage_0    : std_logic_vector(7 downto 0);
// PS/2 Keyboard
wire [4:0]  kb_do_bus;
wire [4:0]  kb_f_bus;
wire [7:0]  key_scancode;
// MC146818A
wire        mc146818a_wr;
//signal mc146818a_rd		: std_logic;
wire [7:0]  mc146818a_do_bus;
wire        port_bff7;
reg [7:0]   port_eff7_reg;
reg         ena_0_4375mhz;
wire [7:0]  gluclock_addr;
// Soundrive
wire [7:0]  covox_a;
wire [7:0]  covox_b;
wire [7:0]  covox_c;
wire [7:0]  covox_d;
// TurboSound
wire        ssg_sel;
wire [7:0]  ssg_cn0_bus;
wire [7:0]  ssg_cn0_a;
wire [7:0]  ssg_cn0_b;
wire [7:0]  ssg_cn0_c;
wire [7:0]  ssg_cn1_bus;
wire [7:0]  ssg_cn1_a;
wire [7:0]  ssg_cn1_b;
wire [7:0]  ssg_cn1_c;
// clock
wire        f0;
wire        f1;
wire        h0;
wire        h1;
wire        c0;
wire        c1;
wire        c2;
wire        c3;
wire        ay_clk;
wire        zclk;
wire        zpos;
wire        zneg;
//signal dos_on		: std_logic;
//signal dos_off		: std_logic;
wire        vdos;
wire        pre_vdos;
wire        vdos_off;
wire        vdos_on;
wire        dos_change;
//signal dos_stall	: std_logic;
// out zsignals
wire        m1;
//signal rfsh			: std_logic;
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
//signal memrw			: std_logic;
wire        opfetch;
wire        intack;
// strobre
wire        iorq_s;
//signal mreq_s		: std_logic;
wire        iord_s;
wire        iowr_s;
wire        iorw_s;
//signal memrd_s		: std_logic;
wire        memwr_s;
//signal memrw_s		: std_logic;
wire        opfetch_s;
// zports OUT
wire [7:0]  dout_ports;
wire        ena_ports;
wire [31:0] xt_page;
wire [4:0]  fmaddr;
wire [7:0]  sysconf;
wire [7:0]  memconf;
//signal fddvirt		: std_logic_vector(3 downto 0);
//signal im2v_frm		: std_logic_vector(2 downto 0);
//signal im2v_lin		: std_logic_vector(2 downto 0);
//signal im2v_dma		: std_logic_vector(2 downto 0);
wire [7:0]  intmask;
wire [8:0]  dmaport_wr;
//signal mus_in_TS   : std_logic_vector(7 downto 0);
// VIDEO_TS
wire        go_arbiter;
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
wire [15:0] dram_rdata;		// raw, should be latched by c2 (video_next)
wire        video_next;
wire        video_pre_next;
wire        next_video;
wire        video_strobe;
wire        video_next_strobe;
// TS
wire [20:0] ts_addr;
wire        ts_req;
wire        ts_z80_lp;
// IN
wire        ts_pre_next;
wire        ts_next;
// TM
wire [20:0] tm_addr;
wire        tm_req;
// Video
wire        tm_next;
// DMA
wire        dma_rnw;
wire        dma_req;
wire        dma_z80_lp;
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
wire        spi_stb;
wire        spi_start;
wire        dma_spi_req;
wire [7:0]  dma_spi_din;
wire        cpu_spi_req;
wire [7:0]  cpu_spi_din;
wire [7:0]  spi_dout;
// HDMI
wire        clk_hdmi;
wire        csync_ts;
wire        hdmi_d1_sig;

wire [7:0]  mouse_do;

// General Sound
wire [14:0] gs_l;
wire [14:0] gs_r;
wire [7:0]  gs_do_bus;
wire        gs_sel;
reg         ce_gs;

// SAA1099
wire        saa_wr_n;
wire [7:0]  saa_out_l;
wire [7:0]  saa_out_r;
wire        ce_saa;
   
clock TS01
(
	.clk(clk_28mhz),
	.ay_mod(0),
	.f0(f0),
	.f1(f1),
	.h0(h0),
	.h1(h1),
	.c0(c0),
	.c1(c1),
	.c2(c2),
	.c3(c3),
	.ce_saa(ce_saa)
);

zclock TS02
(
	.clk(clk_28mhz),
	.c1(c1),
	.c3(c3),
	.c14Mhz(c1),
	.zclk_out(zclk),
	.zpos(zpos),
	.zneg(zneg),
	.iorq_s(iorq_s),
	.dos_on(dos_change),
	.vdos_off(vdos_off),
	.cpu_stall(cpu_stall),
	.ide_stall(0),
	.external_port(0),
	.turbo(turbo)
);

T80s #(.mode(0), .t2write(1), .iowait(1)) z80_unit
(
	.reset_n((~reset)),
	.clk_n(zclk),
	.cen(1'b1),
	.wait_n(1'b1),
	.int_n(cpu_int_n_TS),
	.nmi_n(1'b1),
	.busrq_n(1'b1),
	.m1_n(cpu_m1_n),
	.mreq_n(cpu_mreq_n),
	.iorq_n(cpu_iorq_n),
	.rd_n(cpu_rd_n),
	.wr_n(cpu_wr_n),
	.rfsh_n(cpu_rfsh_n),
	.a(cpu_a_bus),
	.di(cpu_di_bus),
	.do(cpu_do_bus)
);

zsignals TS04
(
	.clk(clk_28mhz),
	.zpos(zpos),
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
	.zclk(zclk),
	.clk(clk_28mhz),
	.din(cpu_do_bus),
	.dout(dout_ports),
	.dataout(ena_ports),
	.a(cpu_a_bus),
	.rst(reset),
	.loader(zports_loader),		//loader, 		-- for load ROM, SPI should be enable
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
	.iorw(iorw),
	.iorw_s(iorw_s),
	.external_port(),		// asserts for AY and VG93 accesses
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
	.sysconf(sysconf),
	.memconf(memconf),
	.cacheconf(cacheconf),
	//im2v_frm	=> im2v_frm,
	//im2v_lin	=> im2v_lin,
	//im2v_dma	=> im2v_dma,
	.intmask(intmask),
	.dmaport_wr(dmaport_wr),		// dmaport_wr
	.dma_act(dma_act),		// from DMA (status of DMA) 
	.dos(dos),
	.vdos(vdos),
	.vdos_on(vdos_on),
	.vdos_off(vdos_off),
	.rstrom(2'b11),
	.tape_read(1'b1),
	//	ide_in		=> "0000000000000000",
	//	ide_out		=> open,
	//	ide_cs0_n	=> open,
	//	ide_cs1_n 	=> open,
	//	ide_req		=> open,
	//	ide_stb		=> '0',
	//	ide_ready	=> '0',
	//	ide_stall	=> open,
	.keys_in(kb_do_bus),		// keys (port FE)
	.mus_in(mouse_do),		// mouse (xxDF)
	.kj_in(joystick),
	.vg_intrq(1'b0),
	.vg_drq(1'b0),		// from vg93 module - drq + irq read
	.sdcs_n(SD_CS_N),		// to SD card
	.sd_start(cpu_spi_req),		// to SPI
	.sd_datain(cpu_spi_din),		// to SPI(7 downto 0);
	.sd_dataout(spi_dout),		// from SPI(7 downto 0); 
	.gluclock_addr(gluclock_addr),
	.wait_read(mc146818a_do_bus),
	.com_data_rx(8'b00000000),		//uart_do_bus,
	.com_status(8'b10010000),		//'1' & uart_tx_empty & uart_tx_fifo_empty & "1000" & uart_rx_avail,
	//com_status=> '0' & uart_tx_empty & uart_tx_fifo_empty & "0000" & '1',
	.lock_conf(1'b1)
);

zmem TS06
(
	.clk(clk_28mhz),
	.c0(c0),
	.c1(c1),
	.c2(c2),
	.c3(c3),
	.zneg(zneg),
	.zpos(zpos),
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
	.csvrom(csvrom),
	.dos(dos),
	.dos_change(dos_change),
	.vdos(vdos),
	.pre_vdos(pre_vdos),
	.vdos_on(vdos_on),
	.vdos_off(vdos_off),
	.cpu_req(cpu_req),
	.cpu_addr(cpu_addr_20),
	.cpu_wrbsel(cpu_wrbsel),		// for 16bit data
	//cpu_rddata=> sdr_do_bus_16, 	-- RD from SDRAM (cpu_strobe=HI and clk)
	.cpu_rddata(sdr2cpu_do_bus_16),
	.cpu_next(cpu_next),
	.cpu_strobe(cpu_strobe),		// from ARBITER ACTIVE=HI 	
	.cpu_latch(cpu_latch),
	.cpu_stall(cpu_stall),		// for Zclock if HI-> STALL (ZCLK)
	.loader(loader),		// ROM for loader active
	.testkey(1'b1),
	.intt(1'b0)
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
	.video_addr({3'b000, video_addr}),		// during access block, only when video_strobe==1
	.go(go_arbiter),		// start video access blocks
	.video_bw(video_bw),		// ZX="11001", [4:3] -total cycles: 11 = 8 / 01 = 4 / 00 = 2
	.video_pre_next(video_pre_next),
	.video_next(video_next),		// (c2) at this signal video_addr may be changed; it is one clock leading the video_strobe
	.video_strobe(video_strobe),		// (c3) one-cycle strobe meaning that video_data is available
	.video_next_strobe(video_next_strobe),
	.next_vid(next_video),		// used for TM prefetch
	//cpu_addr	=> cpu_addr,
	.cpu_addr({cpu_addr_ext, cpu_addr_20}),
	.cpu_wrdata(cpu_do_bus),
	.cpu_req(cpu_req),
	.cpu_rnw(rd),
	.cpu_wrbsel(cpu_wrbsel),
	.cpu_next(cpu_next),		// next cycle is allowed to be used by CPU
	.cpu_strobe(cpu_strobe),		// c2 strobe
	.cpu_latch(cpu_latch),		// c2-c3 strobe
	.curr_cpu_o(curr_cpu),
	.dma_addr({3'b000, dma_addr}),
	.dma_wrdata(dma_wrdata),
	.dma_req(dma_req),
	.dma_z80_lp(dma_z80_lp),
	.dma_rnw(dma_rnw),
	.dma_next(dma_next),
	.ts_addr({3'b000, ts_addr}),
	.ts_req(ts_req),
	.ts_z80_lp(ts_z80_lp),
	.ts_pre_next(ts_pre_next),
	.ts_next(ts_next),
	.tm_addr({3'b000, tm_addr}),
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
	.a(cpu_a_bus),
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
	.dram_rdata(dram_rdata),		// raw, should be latched by c2 (video_next)
	.video_next(video_next),
	.video_pre_next(video_pre_next),
	.next_video(next_video),
	.video_strobe(video_strobe),
	.video_next_strobe(video_next_strobe),
	.ts_addr(ts_addr),
	.ts_req(ts_req),
	.ts_z80_lp(ts_z80_lp),
	.ts_pre_next(ts_pre_next),
	.ts_next(ts_next),
	.tm_addr(tm_addr),
	.tm_req(tm_req),
	.tm_next(tm_next),
	.cfg_60hz(1),		// 0-60Hz, 1-48Hz
	.sync_pol(0),		// 0-positive, 1-negative
	.vga_on(0)		// 1-31kHZ
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
	.dma_z80_lp(dma_z80_lp),
	.dram_rnw(dma_rnw),
	.dram_next(dma_next),
	.spi_rddata(spi_dout),
	.spi_wrdata(dma_spi_din),
	.spi_req(dma_spi_req),
	.spi_stb(spi_stb),
	.spi_start(spi_start),
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
	.sfile_we(sfile_we)
);
   
   
spi TS11
(
	.clk(clk_28mhz),
	.sck(SD_CLK),
	.sdo(SD_SI),
	.sdi(SD_SO),
	.stb(spi_stb),
	.start(spi_start),
	.dma_req(dma_spi_req),
	.dma_din(dma_spi_din),
	.cpu_req(cpu_spi_req),
	.cpu_din(cpu_spi_din),
	.dout(spi_dout),
	.speed(2'b00)
);

zint TS13
(
	.clk(clk_28mhz),
	.zclk(zclk),
	.res(reset),
	.int_start_frm(int_start_frm),		//< N1 VIDEO
	.int_start_lin(int_start_lin),		//< N2 VIDEO
	.int_start_dma(int_start_dma),		//< N3 DMA
	.vdos(pre_vdos),		// vdos,--pre_vdos
	.intack(intack),		//< zsignals  === (intack ? im2vect : 8'hFF)));
	//im2v_frm	=> im2v_frm, 		--< ZPORT (2 downto 0); 
	//im2v_lin	=> im2v_lin, 		--< ZPORT (2 downto 0);
	//im2v_dma	=> im2v_dma, 		--< ZPORT (2 downto 0);
	.intmask(intmask),		//< ZPORT (7 downto 0);
	.im2vect(im2vect),		//> CPU Din (2 downto 0); 	
	.int_n(cpu_int_n_TS)
);
   
// ROM
dpram #(.ADDRWIDTH(13), .MEM_INIT_FILE("src/loader_fat32/loader.mif")) SE1
(
	.clock(clk_28mhz),
	.address_a(cpu_a_bus[12:0]),
	.q_a(rom_do_bus)
);
   
// SDRAM Controller
sdram SE4
(
	.clk(clk_84mhz),
	.clk_28mhz(clk_28mhz),
	.c0(c0),
	.c3(c3),
	.curr_cpu(curr_cpu),		// from arbiter for luch DO_cpu
	.loader(loader),		// loader = 1: wr to ROM 
	.bsel(dram_bsel),
	.a(dram_addr),
	.di(dram_wrdata),
	.do(sdr_do_bus_16),
	.do_cpu(sdr2cpu_do_bus_16),
	.req(dram_req),
	.rnw(dram_rnw),
	.cke(SDRAM_CKE),
	.ras_n(SDRAM_RAS_N),
	.cas_n(SDRAM_CAS_N),
	.we_n(SDRAM_WE_N),
	.cs_n(SDRAM_CS_N),
	.ba(SDRAM_BA),
	.ma(SDRAM_A),
	.dq(SDRAM_DQ[15:0]),
	.dqml(SDRAM_DQML),
	.dqmh(SDRAM_DQMH)
);

keyboard SE5
(
	.clk(clk_28mhz),
	.reset(COLD_RESET | WARM_RESET),
	.a(cpu_a_bus[15:8]),
	.keyb(kb_do_bus),
	.keyf(kb_f_bus),
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

mc146818a SE9
(
	.reset(reset),
	.clk(clk_28mhz),
	.ena(ena_0_4375mhz),
	.cs(1'b1),
	.keyscancode(key_scancode),
	.rtc(RTC),
	.cmoscfg(CMOSCfg),
	.wr(mc146818a_wr),
	.a(gluclock_addr[7:0]),
	.di(cpu_do_bus),
	.do(mc146818a_do_bus)
);
   
// Soundrive
soundrive SE10
(
	.reset(reset),
	.clk(clk_28mhz),
	.cs(1'b1),
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

// TurboSound
turbosound SE12
(
	.reset(reset),
	.clk(clk_28mhz),
	.ena(ena_1_75mhz),
	.a(cpu_a_bus),
	.di(cpu_do_bus),
	.wr_n(cpu_wr_n),
	.iorq_n(cpu_iorq_n),
	.m1_n(cpu_m1_n),
	.sel(ssg_sel),
	.cn0_do(ssg_cn0_bus),
	.cn0_a(ssg_cn0_a),
	.cn0_b(ssg_cn0_b),
	.cn0_c(ssg_cn0_c),
	.cn1_do(ssg_cn1_bus),
	.cn1_a(ssg_cn1_a),
	.cn1_b(ssg_cn1_b),
	.cn1_c(ssg_cn1_c)
);
   
always @(posedge clk_84mhz) begin
	ce_gs <= clk_28mhz;
	if(ce_gs) ce_gs <= 0;
end

gs #("src/sound/gs105b.mif") U15
(
	.RESET(reset),
	.CLK(clk_84mhz),
	.CE(ce_gs),
	
	.A(cpu_a_bus[3]),
	.DI(cpu_do_bus),
	.DO(gs_do_bus),
	.CS_n(cpu_iorq_n | (~gs_sel)),
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

saa1099 U16
(
	.clk_sys(clk_28mhz),
	.ce(ce_saa),
	.rst_n((~reset)),
	.cs_n(1'b0),
	.a0(cpu_a_bus[8]),		// 0=data, 1=address
	.wr_n(saa_wr_n),
	.din(cpu_do_bus),
	.out_l(saa_out_l),
	.out_r(saa_out_r)
);
   
//-----------------------------------------------------------------------------
// Global
//-----------------------------------------------------------------------------
assign reset = COLD_RESET | WARM_RESET | kb_f_bus[1];		// Reset
assign RESET_OUT = reset;

always @(negedge clk_28mhz) begin
	ena_cnt <= ena_cnt + 1'd1;
	ena_1_75mhz <= ~ena_cnt[3] & ena_cnt[2] & ena_cnt[1] & ena_cnt[0];
	ena_0_4375mhz <= ~ena_cnt[5] & ena_cnt[4] & ena_cnt[3] & ena_cnt[2] & ena_cnt[1] & ena_cnt[0];
end

// CPU interface
assign cpu_addr_ext = (loader && (cpu_a_bus[15:14] == 2'b10 || cpu_a_bus[15:14] == 2'b11)) ? 3'b100 : {csvrom, 2'b00};

assign dram_rdata = sdr_do_bus_16;

assign gs_sel = (GS_ENA && ~cpu_iorq_n && cpu_m1_n && cpu_a_bus[7:4] == 4'b1011 && cpu_a_bus[2:0] == 3'b011);

assign cpu_di_bus = (loader && ~cpu_mreq_n && ~cpu_rd_n && !cpu_a_bus[15:13]) ? rom_do_bus : 		// loader ROM
						  (~cpu_mreq_n && ~cpu_rd_n) ? sdr_do_bus : 		// SDRAM
						  (intack) ? im2vect : 
						  (~cpu_iorq_n && ~cpu_rd_n && port_bff7 && port_eff7_reg[7]) ? mc146818a_do_bus : 		// MC146818A
						  (gs_sel && ~cpu_rd_n) ? gs_do_bus : 		// General Sound
						  (~cpu_iorq_n && ~cpu_rd_n && cpu_a_bus == 16'hFFFD && ~ssg_sel) ? ssg_cn0_bus : 		// TurboSound
						  (~cpu_iorq_n && ~cpu_rd_n && cpu_a_bus == 16'hFFFD &&  ssg_sel) ? ssg_cn1_bus : 
						  (~cpu_iorq_n && ~cpu_rd_n && cpu_a_bus == 16'h0001) ? key_scancode : 
						  (ena_ports) ? dout_ports : 
						  8'b11111111;

assign zports_loader = loader & ~port_xx01_reg[0]; 		// enable zports_loader only for SPI flash loading mode

always @(posedge clk_28mhz) begin
	if(COLD_RESET) begin
		port_xx01_reg <= 1;		// bit2 = (0:Loader ON, 1:Loader OFF); bit0 = (0:FLASH, 1:SD)
		loader <= 1;
	end
	else begin
		if (~cpu_iorq_n && ~cpu_wr_n && cpu_a_bus[7:0] == 1) port_xx01_reg <= cpu_do_bus;
		if (~cpu_m1_n && ~cpu_mreq_n && !cpu_a_bus && port_xx01_reg[2]) loader <= 0;
	end
end

always @(posedge clk_28mhz) begin
	if (reset) begin
		port_xxfe_reg <= 0;
		port_eff7_reg <= 0;
	end
	else begin
		if (~cpu_iorq_n && ~cpu_wr_n && cpu_a_bus[7:0] == 8'hFE) port_xxfe_reg <= cpu_do_bus;
		if (~cpu_iorq_n && ~cpu_wr_n && cpu_a_bus == 16'hEFF7) port_eff7_reg <= cpu_do_bus;	//for RTC
	end 
end

// TURBO
assign turbo = (loader) ? 2'b11 : sysconf[1:0];

// RTC
assign mc146818a_wr = port_bff7 && ~cpu_wr_n;
assign port_bff7 = ~cpu_iorq_n && cpu_a_bus == 16'hBFF7 && cpu_m1_n && port_eff7_reg[7];

// SAA1099
assign saa_wr_n = ~cpu_iorq_n && ~cpu_wr_n && cpu_a_bus[7:0] == 8'hFF && ~dos;

assign SOUND_L = ({3'b000, port_xxfe_reg[4], 12'b000000000000}) + ({3'b000, ssg_cn0_a, 5'b00000}) + ({4'b0000, ssg_cn0_b, 4'b0000}) + ({3'b000, ssg_cn1_a, 5'b00000}) + ({4'b0000, ssg_cn1_b, 4'b0000}) + ({2'b00, covox_a, 6'b000000}) + ({2'b00, covox_b, 6'b000000}) + ({gs_l[14], gs_l}) + ({1'b0, saa_out_l, 7'b0000000});
assign SOUND_R = ({3'b000, port_xxfe_reg[4], 12'b000000000000}) + ({3'b000, ssg_cn0_c, 5'b00000}) + ({4'b0000, ssg_cn0_b, 4'b0000}) + ({3'b000, ssg_cn1_c, 5'b00000}) + ({4'b0000, ssg_cn1_b, 4'b0000}) + ({2'b00, covox_c, 6'b000000}) + ({2'b00, covox_d, 6'b000000}) + ({gs_r[14], gs_r}) + ({1'b0, saa_out_r, 7'b0000000});
   
endmodule
