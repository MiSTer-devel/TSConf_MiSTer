`include "tune.v"

// Pentevo project(c) NedoPC 2008-2011
//
// top-level

module tsconf
(
  // Clocks
  input         clk,
  input         fclk,
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
  output  [7:0] VRED,
  output  [7:0] VGRN,
  output  [7:0] VBLU,
  output        VHSYNC,
  output        VVSYNC,
  output        VGA_HBLANK,
  output        VGA_VBLANK,
  output        VGA_CEPIX,
  output        VGA_HIRES,

  // SD/MMC Memory Card
  input         SD_SO,
  output        SD_SI,
  output        SD_CLK,
  output        SD_CS_N,
`ifdef SD_CARD2
  output        SD_CS2_N,
`endif

  // Audio
  output signed [15:0] SOUND_L,
  output signed [15:0] SOUND_R,

  // Misc. I/O
  input         RESET,
  output        RESET_OUT,
  input  [64:0] RTC,
  input         TAPE_IN,
  output reg    MIDI_OUT = 1'b0,
  input         UART_RX,
  output        UART_TX,

  // Configuration bits
  input         CFG_OUT0,
  input         CFG_60HZ,
  input         CFG_SCANDOUBLER,
  input         CFG_VDAC,
  input   [2:0] CFG_JOYSTICK1,
  input   [2:0] CFG_JOYSTICK2,
  input         CFG_TURBOSOUND_ACB,
  input         CFG_AUDIO_BOOST,

  // User input
  input  [10:0] PS2_KEY,
  input  [28:0] PS2_MOUSE,
  input   [7:0] JOYSTICK1,
  input   [7:0] JOYSTICK2,

  input         loader_act,
  input  [15:0] loader_addr,
  input   [7:0] loader_do,
  input         loader_wr,
  input         loader_cs_rom_main,
  input         loader_cs_rom_gs,

  input   [7:0] cmos_addr,
  input   [7:0] cmos_do,
  output  [7:0] cmos_di,
  input         cmos_wr
);

  wire f0, f1, h0, h1, c0, c1, c2, c3;
  wire rst_n; // global reset
  wire genrst;

  wire spi_mode;

  wire [1:0] ay_mod;
  wire dos;
  wire vdos;
  wire pre_vdos;
  wire zpos, zneg;
  wire [7:0] zports_dout;
  wire zports_dataout;
  wire porthit;
  wire [1:0] dmawpdev;
  wire [7:0] kbd_data;
  wire [2:0] kbd_data_sel;
  wire [7:0] mus_data = 8'h00;
  wire kbd_stb, mus_xstb, mus_ystb, mus_btnstb, kj_stb;
  wire [4:0] kbd_port_data;

`ifdef KEMPSTON_8BIT
  wire [7:0] kj_port_data;
`else
  wire [4:0] kj_port_data;
`endif

  wire [7:0] mus_port_data;
  wire [7:0] wait_read,wait_write;
  wire wait_start_gluclock;
  wire wait_start_comport;
  wire wait_end;
  wire [7:0] wait_addr;
  wire [1:0] wait_status;

  // config signals
  wire cfg_tape_sound = 1'b0;
  wire cfg_floppy_swap = 1'b0;
  wire int_start_wtp = 1'b0;
  wire cfg_60hz = CFG_60HZ;
  wire beeper_mux; // what is mixed to FPGA beeper output - beeper(0) or tapeout(1)
  wire tape_read;  // tapein data
  wire set_nmi;
  wire cfg_vga_on = CFG_SCANDOUBLER;

  // nmi signals
  wire gen_nmi;
  wire clr_nmi;
  wire in_nmi;

  wire tape_in;
  wire [7:0] zmem_dout;
  wire zmem_dataout;
  wire [7:0] received;
  wire [7:0] tobesent;
  wire intrq = 1'b1, drq = 1'b1;
  wire vg_wrFF;
  wire zclk = ~clkz_out;

  // assign nmi_n = gen_nmi ? 1'b0 : 1'bZ;
  wire video_go;
  wire beeper_wr, covox_wr;
  wire external_port;
  wire ide_stall;

  wire [8:0] ray_x;
  wire [8:0] ray_y;

  wire rampage_wr;        // ports #10AF-#13AF
  wire [7:0] memconf;
  wire [7:0] xt_ramp[0:3];
  wire [4:0] rompg;
  wire [7:0] sysconf;

`ifdef FORCE_14MHZ
  wire [1:0] turbo = 2'b10;
`elsif SIMULATE
  wire [1:0] turbo = 2'b10;
`else
  wire [1:0] turbo = sysconf[1:0];
`endif
  wire [3:0] cacheconf;
  wire [7:0] border;
  wire line_start_s;
  wire frame_start_s;
  wire int_start_frm;
  wire int_start_dma;

  wire [7:0] dout_ram;
  wire [7:0] dout_ports;
  wire [7:0] im2vect;
  wire ena_ram;
  wire ena_ports;
  wire drive_ff;

  wire vdos_on, vdos_off;
  wire dos_on, dos_off;

  wire [22:0] daddr;
  wire dreq;
  wire drnw;
  wire [15:0] dram_rd_r;
  wire [15:0] dram_wrdata;
  wire [1:0] dbsel;

  wire cpu_req, cpu_wrbsel, cpu_strobe, cpu_latch;
  wire [20:0] cpu_addr;
  wire [20:0] video_addr;
  wire cpu_next;
  wire cpu_stall;

  wire [4:0] video_bw;
  wire video_strobe;
  wire video_next;
  wire video_pre_next;
  wire next_video;

  wire [20:0] dma_addr;
  wire [15:0] dma_wrdata;
  wire dma_req;
  wire dma_rnw;
  wire dma_next;
  wire dma_strobe;

  wire [20:0] ts_addr;
  wire ts_req;
  wire ts_pre_next;
  wire ts_next;

  wire [20:0] tm_addr;
  wire tm_req;
  wire tm_next;

  wire dbg_arb;    // DEBUG!!!

  wire border_wr;
  wire zborder_wr;
  wire zvpage_wr;
  wire vpage_wr;
  wire vconf_wr;
  wire gx_offsl_wr;
  wire gx_offsh_wr;
  wire gy_offsl_wr;
  wire gy_offsh_wr;
  wire t0x_offsl_wr;
  wire t0x_offsh_wr;
  wire t0y_offsl_wr;
  wire t0y_offsh_wr;
  wire t1x_offsl_wr;
  wire t1x_offsh_wr;
  wire t1y_offsl_wr;
  wire t1y_offsh_wr;
  wire palsel_wr;
  wire hint_beg_wr;
  wire vint_begl_wr;
  wire vint_begh_wr;
  wire tsconf_wr;
  wire tmpage_wr;
  wire t0gpage_wr;
  wire t1gpage_wr;
  wire sgpage_wr;

  wire [15:0]       zmd;
  wire [7:0]       zma;
  wire cram_we;
  wire sfile_we;
  wire regs_we;
`ifdef COPPER
  wire clist_we;
  wire copper_wr;
  wire copper_int;
  wire copper_rdy;
  wire cpu_xt_access;
`endif

`ifdef PENT_312
  wire boost_start;
  wire [4:0] hcnt;
  wire upper8;
`endif

  wire rst;
  wire m1;
  wire rfsh;
  wire zrd;
  wire zwr;
  wire iorq;
  wire iorq_s;
  // wire iorq_s2;
  wire mreq;
  wire mreq_s;
  wire rdwr;
  wire iord;
  wire iowr;
  wire iordwr;
  wire iord_s;
  wire iowr_s;
  wire iordwr_s;
  wire [7:0] xt_wr_addr;
  wire [7:0] xt_wr_data;
`ifdef COPPER
  wire copper_xt_wr;
  wire [7:0] copper_xt_wr_addr;
  wire [7:0] copper_xt_wr_data;
`endif
  wire memrd;
  wire memwr;
  wire memrw;
  wire memrd_s;
  wire memwr_s;
  wire memrw_s;
  wire opfetch;
  wire opfetch_s;
  wire intack;

  wire [31:0] xt_page;

`ifdef FDR
  wire [9:0] dmaport_wr;
`else
  wire [8:0] dmaport_wr;
`endif
  wire [4:0] fmaddr;

  wire [7:0] fddvirt;

  wire [4:0] vred_raw;
  wire [4:0] vgrn_raw;
  wire [4:0] vblu_raw;
  wire vdac_mode;

  wire [15:0] z80_ide_out;
  wire z80_ide_cs0_n;
  wire z80_ide_cs1_n;
  wire z80_ide_req;
  wire z80_ide_rnw;
  wire [15:0] dma_ide_out;
  wire dma_ide_req;
  wire dma_ide_rnw;
  wire ide_stb;
  wire ide_ready;
  wire [15:0] ide_out;

  wire [7:0] intmask;

  wire dma_act;

  wire [15:0] dma_data;
  wire [7:0] dma_wraddr;
  wire dma_cram_we;
  wire dma_sfile_we;
`ifdef COPPER
  wire dma_clist_we;
`endif

  wire cpu_spi_req;
  wire dma_spi_req;
  wire spi_stb;
  wire spi_start;
  wire [7:0] cpu_spi_din;
  wire [7:0] dma_spi_din;
  wire [7:0] spi_dout;

  wire dma_wtp_req;
  wire dma_wtp_stb = 1'b0;
  wire wait_status_wrn;

  wire res = ~rst_n;

  // z80
  wire [15:0] a;
  wire [7:0]  d;
  wire [7:0]  di;
  wire        mreq_n;
  wire        iorq_n;
  wire        wr_n;
  wire        rd_n;
  wire        int_n;
  wire        m1_n;
  wire        rfsh_n;

  wire        clkz_out;
  wire        csrom;
  wire        curr_cpu;

  wire [15:0] dram_do;
  wire [15:0] dram_docpu;

  wire [1:0]  vred;
  wire [1:0]  vgrn;
  wire [1:0]  vblu;
  wire [7:0]  vred_vdac;
  wire [7:0]  vgrn_vdac;
  wire [7:0]  vblu_vdac;
  assign VRED = CFG_VDAC? vred_vdac : {vred,vred,vred,vred};
  assign VGRN = CFG_VDAC? vgrn_vdac : {vgrn,vgrn,vgrn,vgrn};
  assign VBLU = CFG_VDAC? vblu_vdac : {vblu,vblu,vblu,vblu};

  clock clock
  (
    .clk(fclk),
    .f0(f0),
    .f1(f1),
    .h0(h0),
    .h1(h1),
    .c0(c0),
    .c1(c1),
    .c2(c2),
    .c3(c3),
    // .ay_clk(ay_clk),
    // .ay_mod(sysconf[4:3])
    .ay_mod(2'b00)
  );

  resetter myrst
  (
    .clk(fclk),
    .rst_in_n(~(RESET | key_reset)),
    .rst_out_n(rst_n)
  );
  assign RESET_OUT = ~rst_n;

  zclock zclock
  (
    .clk(fclk),
    .c0(c0),
    .c2(c2),
    .iorq_s(iorq_s),
    .zclk_out(clkz_out),
    .zpos(zpos),
    .zneg(zneg),
    .turbo(turbo),
    .dos_on(dos_on),
    .vdos_off(vdos_off),
    .cpu_stall(cpu_stall),
`ifdef IDE_HDD
    .ide_stall(ide_stall),
`else
    .ide_stall(1'b0),
`endif
`ifdef PENT_312
    .boost_start(boost_start),
    .hcnt(hcnt),
    .upper8(upper8),
`endif
    .external_port(1'b0)
  );


  zmem zmem
  (
    .clk(fclk),
    .c1(c1),
    .c2(c2),
    .c3(c3),
    .rst(rst),
    .zneg(zneg),
    .za(a),
    .zd_out(dout_ram),
    .zd_ena(ena_ram),
    .opfetch(opfetch),
    .opfetch_s(opfetch_s),
    .memrd(memrd),
    .memwr(memwr),
    .memwr_s(memwr_s),
    .memconf(memconf[3:0]),
    .xt_page(xt_page),
    .rompg(rompg),
    .cache_en(cacheconf[3:0]),
    .romoe_n(),
    .romwe_n(),
    .csrom(csrom),
    .dos(dos),
    .dos_on(dos_on),
    .dos_off(dos_off),
    .vdos(vdos),
    .pre_vdos(pre_vdos),
    .vdos_on(vdos_on),
    .vdos_off(vdos_off),
    .cpu_req(cpu_req),
    .cpu_wrbsel(cpu_wrbsel),
    .cpu_strobe(cpu_strobe),
    .cpu_latch(cpu_latch),
    .cpu_addr(cpu_addr),
    .cpu_rddata(dram_docpu),           // raw
    .cpu_stall(cpu_stall),
    .cpu_next(cpu_next),
    .turbo(turbo)
  );

  sdram sdram
  (
    .clk(clk),
    .cyc(ce&c3),
    .port1_curr_cpu(curr_cpu),
    .port1_bsel(dbsel),
    .port1_a(daddr),
    .port1_di(dram_wrdata),
    .port1_do(dram_do),
    .port1_do_cpu(dram_docpu),
    .port1_req(dreq),
    .port1_rnw(drnw),
    .port2_bsel(gs_dram_bsel),
    .port2_a(gs_dram_addr),
    .port2_di(gs_dram_di),
    .port2_do(gs_dram_do),
    .port2_req(gs_dram_req),
    .port2_rnw(gs_dram_rnw),
    .port2_ack(gs_dram_ack),
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

  arbiter arbiter
  (
    .clk(fclk),
    .c1(c1),
    .c2(c2),
    .c3(c3),
    .cyc(ce&c3),
    .dram_addr(daddr),
    .dram_req(dreq),
    .dram_rnw(drnw),
    .dram_bsel(dbsel),
    .dram_wrdata(dram_wrdata),
    .cpu_addr(cpu_addr),
    .cpu_wrdata(d),
    .cpu_req(cpu_req),
    .cpu_rnw(zrd | csrom),
    .cpu_wrbsel(cpu_wrbsel),
    .cpu_csrom(csrom),
    .cpu_next(cpu_next),
    .cpu_strobe(cpu_strobe),
    .cpu_latch(cpu_latch),
    .curr_cpu_o(curr_cpu),
    .video_go(video_go),
    .video_bw(video_bw),
    .video_addr(video_addr),
    .video_strobe(video_strobe),
    .video_pre_next(video_pre_next),
    .video_next(video_next),
    .next_vid(next_video),
    .dma_addr(dma_addr),
    .dma_wrdata(dma_wrdata),
    .dma_req(dma_req),
    .dma_rnw(dma_rnw),
    .dma_next(dma_next),
    .ts_req(ts_req),
    .ts_addr(ts_addr),
    .ts_pre_next(ts_pre_next),
    .ts_next(ts_next),
    .tm_addr(tm_addr),
    .tm_req(tm_req),
    .tm_next(tm_next),
    .loader_clk(clk),
    .loader_addr(loader_addr),
    .loader_data(loader_do),
    .loader_wr(loader_wr),
    .loader_cs_rom_main(loader_cs_rom_main),
    .loader_cs_rom_gs(loader_cs_rom_gs)
  );

  video_top video_top
  (
    .clk(fclk),
    .res(res),
    .f1(f1),
    .h1(h1),
    .c0(c0),
    .c1(c1),
    .c3(c3),
    .vred(vred),
    .vgrn(vgrn),
    .vblu(vblu),
    .vred_raw(vred_raw),
    .vgrn_raw(vgrn_raw),
    .vblu_raw(vblu_raw),
    .vdac_mode(vdac_mode),
`ifdef IDE_VDAC2
    .vdac2_msel(vdac2_msel),
`endif
    .hsync(VHSYNC),
    .vsync(VVSYNC),
    .hblank(VGA_HBLANK),
    .vblank(VGA_VBLANK),
    .pix_stb(VGA_CEPIX),
    .tv_hires(VGA_HIRES),
    .csync(),
    .ray_x(ray_x),
    .ray_y(ray_y),
    .cfg_60hz(cfg_60hz),
    .vga_on(cfg_vga_on),
    .border_wr(border_wr),
    .zborder_wr(zborder_wr),
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
    .palsel_wr(palsel_wr),
    .hint_beg_wr(hint_beg_wr),
    .vint_begl_wr(vint_begl_wr),
    .vint_begh_wr(vint_begh_wr),
    .tsconf_wr(tsconf_wr),
    .tmpage_wr(tmpage_wr),
    .t0gpage_wr(t0gpage_wr),
    .t1gpage_wr(t1gpage_wr),
    .sgpage_wr(sgpage_wr),
    .video_addr(video_addr),
    .video_bw(video_bw),
    .video_go(video_go),
    .dram_rdata(dram_do),               // raw, should be latched by c2
    .video_strobe(video_strobe),
    .video_pre_next(video_pre_next),
    .ts_req(ts_req),
    .ts_pre_next(ts_pre_next),
    .ts_addr(ts_addr),
    .ts_next(ts_next),
    .tm_addr(tm_addr),
    .tm_req(tm_req),
    .tm_next(tm_next),
`ifdef PENT_312
    .hcnt(hcnt),
    .upper8(upper8),
`endif
    .d(d),
    .xt_wr_data(xt_wr_data),
    .zmd(zmd),
    .zma(zma),
    .cram_we(cram_we),
    .sfile_we(sfile_we),
    .int_start_s(int_start_frm),
    .line_start_s(line_start_s),
    .frame_start_s(frame_start_s)
  );

`ifdef COPPER
  copper copper
  (
    .clk          (fclk),
    .res          (res),
    .cpu_data     (d),
    .cpu_wr       (copper_wr),
    .cpu_xt_access(cpu_xt_access),
    .cl_wr_addr   (zma),
    .cl_wr_data   (zmd),
    .cl_wr        (clist_we),
    .ts_reg_addr  (copper_xt_wr_addr),
    .ts_reg_data  (copper_xt_wr_data),
    .ts_reg_wr    (copper_xt_wr),
    .sig_int      (copper_int),
    .sig_rdy      (copper_rdy),
    .ray_x        (ray_x[8:1]),
    .ray_y        (ray_y),
    .dma_done     (!dma_act),
    .line_start_s (line_start_s),
    .frame_start_s(frame_start_s)
  );
`endif

  vdac vdac
  (
    .mode(vdac_mode),
    .o_r(vred_raw),
    .o_g(vgrn_raw),
    .o_b(vblu_raw),
    .v_r(vred_vdac),
    .v_g(vgrn_vdac),
    .v_b(vblu_vdac)
  );

  zmaps zmaps
  (
    .clk(fclk),
    .memwr_s(memwr_s),
    .a(a),
    .d(d),
    .fmaddr(fmaddr),
    .zmd(zmd),
    .zma(zma),
`ifdef COPPER
    .dma_clist_we(dma_clist_we),
    .clist_we(clist_we),
`endif
    .dma_wraddr(dma_wraddr),
    .dma_data(dma_data),
    .dma_cram_we(dma_cram_we),
    .dma_sfile_we(dma_sfile_we),
    .cram_we(cram_we),
    .sfile_we(sfile_we),
    .regs_we(regs_we)
  );

  zsignals zsignals
  (
    .clk(fclk),
    .zpos(zpos),
    .rst_n(rst_n),
    .iorq_n(iorq_n),
    .mreq_n(mreq_n),
    .m1_n(m1_n),
    .rfsh_n(rfsh_n),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .rst(rst),
    .m1(m1),
    .rfsh(rfsh),
    .rd(zrd),
    .wr(zwr),
    .iorq(iorq),
    .iorq_s(iorq_s),
    // .iorq_s2    (iorq_s2),
    .mreq(mreq),
    .mreq_s(mreq_s),
    .rdwr(rdwr),
    .iord(iord),
    .iowr(iowr),
    .iordwr(iordwr),
    .iord_s(iord_s),
    .iowr_s(iowr_s),
    .iordwr_s(iordwr_s),
    .memrd(memrd),
    .memwr(memwr),
    .memrw(memrw),
    .memrd_s(memrd_s),
    .memwr_s(memwr_s),
    .memrw_s(memrw_s),
    .opfetch(opfetch),
    .opfetch_s(opfetch_s),
    .intack(intack)
  );

  zports zports
  (
    .zclk(fclk),
    .clk(fclk),
    .din(d),
    .dout(dout_ports),
    .dataout(ena_ports),
    .a(a),
    .rst(rst),
    .opfetch(opfetch),
    .rd(zrd),
    .wr(zwr),
    .rdwr(rdwr),
    .iorq(iorq),
    .iord(iord),
    .iowr(iowr),
    .iordwr(iordwr),
    .iorq_s(iorq_s),
    .iord_s(iord_s),
    .iowr_s(iowr_s),
    .iordwr_s(iordwr_s),
`ifdef COPPER
    .copper_xt_wr(copper_xt_wr),
    .copper_xt_wr_addr(copper_xt_wr_addr),
    .copper_xt_wr_data(copper_xt_wr_data),
`endif
    .ay_bdir(),
    .ay_bc1(),
    .vg_intrq(intrq),
    .vg_drq(drq),
    .vg_cs_n(),
    .vg_wrFF(vg_wrFF),
    .sd_start(cpu_spi_req),
    .sd_dataout(spi_dout),
    .sd_datain(cpu_spi_din),
    .sdcs_n(SD_CS_N),
`ifdef SD_CARD2
    .sd2cs_n(SD_CS2_N),
`endif
    .spi_mode(spi_mode),
`ifdef IDE_VDAC2
    .ftcs_n(ftcs_n),
`ifdef ESP32_SPI
    .espcs_n(espcs_n),
    .espcs_in(espcs_in),
    .esp_ft_spi_dis(esp_ft_spi_dis),
`endif
`endif
`ifdef IDE_HDD
    .ide_in(ide_d),
    .ide_out(z80_ide_out),
    .ide_cs0_n(z80_ide_cs0_n),
    .ide_cs1_n(z80_ide_cs1_n),
    .ide_req(z80_ide_req),
    .ide_stb(ide_stb),
    .ide_ready(ide_ready),
    .ide_stall(ide_stall),
`endif
    .xt_wr_addr(xt_wr_addr),
    .xt_wr_data(xt_wr_data),
    .border_wr(border_wr),
    .zborder_wr(zborder_wr),
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
    .palsel_wr(palsel_wr),
    .hint_beg_wr(hint_beg_wr),
    .vint_begl_wr(vint_begl_wr),
    .vint_begh_wr(vint_begh_wr),
    .tsconf_wr(tsconf_wr),
    .tmpage_wr(tmpage_wr),
    .t0gpage_wr(t0gpage_wr),
    .t1gpage_wr(t1gpage_wr),
    .sgpage_wr(sgpage_wr),
    .xt_page(xt_page),
    .fmaddr(fmaddr),
    .regs_we(regs_we),
    .sysconf(sysconf),
    .cacheconf(cacheconf),
    .memconf(memconf),
    .intmask(intmask),
    .fddvirt(fddvirt),
`ifdef COPPER
    .copper_wr(copper_wr),
    .copper_rdy(copper_rdy),
    .cpu_xt_access(cpu_xt_access),
`endif
`ifdef FDR
    .fdr_cnt(fdr_cnt),
    .fdr_en(fdr_en),
    .fdr_cnt_lat(fdr_cnt_lat),
`endif
    .cfg_floppy_swap(cfg_floppy_swap),
    .drive_sel(),
    .dos(dos),
    .vdos(vdos),
    .vdos_on(vdos_on),
    .vdos_off(vdos_off),
    .dmaport_wr(dmaport_wr),
    .dma_act(dma_act),
    .dmawpdev(dmawpdev),
    .keys_in(kbd_port_data),
    .mus_in(mus_port_data),
    .kj_in((!CFG_JOYSTICK1? JOYSTICK1 : 0) | (!CFG_JOYSTICK2? JOYSTICK2 : 0)),
    .tape_read(TAPE_IN),
    .beeper_wr(beeper_wr),
    .covox_wr(covox_wr),
    .wait_addr(wait_addr),
    .wait_start_gluclock(wait_start_gluclock),
    .wait_start_comport(wait_start_comport),
    .wait_read(wait_read),
    .wait_write(wait_write),
    .porthit(porthit),
    .external_port(external_port)
  );

  dma dma
  (
    .clk(fclk),
    .c2(c2),
    .rst_n(rst_n),
    .int_start(int_start_dma),
    .zdata(xt_wr_data),
    .dmaport_wr(dmaport_wr),
    .dma_act(dma_act),
    .dram_addr(dma_addr),
    .dram_rnw(dma_rnw),
    .dram_req(dma_req),
    .dram_rddata(dram_do),
    .dram_wrdata(dma_wrdata),
    .dram_next(dma_next),
    .data(dma_data),
    .wraddr(dma_wraddr),
    .cram_we(dma_cram_we),
    .sfile_we(dma_sfile_we),
`ifdef COPPER
    .clist_we(dma_clist_we),
`endif
`ifdef IDE_HDD
    .ide_in(ide_d),
    .ide_out(dma_ide_out),
    .ide_req(dma_ide_req),
    .ide_rnw(dma_ide_rnw),
    .ide_stb(ide_stb),
`endif
`ifdef FDR
    .fdr_in(fdr_rle),
    .fdr_req(fdr_req),
    .fdr_stb(fdr_stb),
    .fdr_stop(fdr_stop),
`endif
    .spi_req(dma_spi_req),
    .spi_stb(spi_start),
    .spi_rddata(spi_dout),
    .spi_wrdata(dma_spi_din),
    .wtp_req(dma_wtp_req),
    .wtp_stb(dma_wtp_stb),
    .wtp_rddata(mus_data)   // data must be available 1 clk earlier than wait_data (mus_data = shift_in in slavespi.v)
    // .wtp_wrdata(dma_wtp_din)
  );

`ifdef FDR
  fddrip fddrip
  (
    .clk(fclk),
    .rdat_n(rdat_b_n),
    .reset(!fdr_en),
    .cnt_latch(fdr_cnt_lat),
    .data(fdr_rle),
    .data_cnt_l(fdr_cnt),
    .req(fdr_req),
    .stb(fdr_stb),
    .stop(fdr_stop)
  );
`endif

  zint zint
  (
    .clk(fclk),
    .zpos(zpos),
    .res(res),
    .wait_n(1'b1),
    .im2vect(im2vect),
    .intmask(intmask),
`ifdef IDE_VDAC2
    .int_start_lin(vdac2_msel ? int_start_ft : line_start_s),
`else
    .int_start_lin(line_start_s),
`endif
`ifdef PENT_312
    .boost_start(boost_start),
`endif
    .int_start_frm(int_start_frm),
    .int_start_dma(int_start_dma),
    .int_start_wtp(int_start_wtp),
`ifdef COPPER
    .int_start_cpr(copper_int),
`endif
    .vdos(pre_vdos),
    .intack(intack),
    .int_n(int_n)
  );

  spi spi
  (
    .clk(fclk),
    .sck(SD_CLK),
    .sdo(SD_SI),
`ifdef IDE_VDAC2
`ifdef ESP32_SPI
    .sdi((!ftcs_n || !espcs_n) ? ftdi : sddi),
`else
    .sdi(!ftcs_n ? ftdi : sddi),
`endif
`else
    .sdi(SD_SO),
`endif
    .mode(spi_mode),
    .dma_req(dma_spi_req),
    .dma_din(dma_spi_din),
    .cpu_req(cpu_spi_req),
    .cpu_din(cpu_spi_din),
    .start(spi_start),
    .dout(spi_dout)
  );

`ifdef IDE_HDD
  ide ide
  (
    .clk(fclk),
    .reset(res),
    .rdy_stb(ide_stb),
    .rdy(ide_ready),
    .ide_out(ide_out),
    .ide_a(ide_a),
    .ide_dir(ide_dir),
    .ide_cs0_n(ide_cs0_n),
    .ide_cs1_n(ide_cs1_n),
    .ide_rd_n(ide_rd_n),
    .ide_wr_n(ide_wr_n),
    .dma_out(dma_ide_out),
    .dma_req(dma_ide_req),
    .dma_rnw(dma_ide_rnw),
    .z80_out(z80_ide_out),
    .z80_a(a[7:5]),
    .z80_cs0_n(z80_ide_cs0_n),
    .z80_cs1_n(z80_ide_cs1_n),
    .z80_req(z80_ide_req),
    .z80_rnw(!rd_n)            // this should be the direct Z80 signal
  );
`endif


  // Z80 CPU
  T80pa CPU
  (
    .RESET_n(rst_n),
    .CLK(fclk),
    .CEN_p(zpos),
    .CEN_n(zneg),
    .INT_n(int_n),
    .M1_n(m1_n),
    .MREQ_n(mreq_n),
    .IORQ_n(iorq_n),
    .RD_n(rd_n),
    .WR_n(wr_n),
    .RFSH_n(rfsh_n),
    .OUT0(CFG_OUT0),
    .A(a),
    .DI(di),
    .DO(d)
  );


  // PS/2 Keyboard
  wire       key_reset;
  wire [7:0] key_scancode;
  wire       key_scancode_ack;
  wire       key_scancode_clr;

  keyboard keyboard
  (
    .clk(clk),
    .reset(RESET),
    .a(a[15:8]),
    .keyb(kbd_port_data),
    .key_reset(key_reset),
    .scancode(key_scancode),
    .scancode_ack(key_scancode_ack),
    .scancode_clr(key_scancode_clr),
    .matrix_update(VVSYNC),
    .ps2_key(PS2_KEY),
    .cfg_joystick1(CFG_JOYSTICK1),
    .cfg_joystick2(CFG_JOYSTICK2),
    .joystick1(JOYSTICK1),
    .joystick2(JOYSTICK2)
  );


  // PS/2 Mouse
  kempston_mouse kempston_mouse
  (
    .clk_sys(clk),
    .reset(rst),
    .ps2_mouse(PS2_MOUSE),
    .addr(a[10:8]),
    .dout(mus_port_data)
  );


  // MC146818A RTC
  reg ena_0_4375mhz;
  always @(posedge clk) begin
    reg [7:0] div;
    if (div == 191)
      div <= 0;
    else
      div <= div + 1'd1;
    ena_0_4375mhz <= !div;
  end

  mc146818a mc146818a
  (
    .RESET(rst),
    .CLK(clk),
    .ENA(ena_0_4375mhz),
    .CS(1),
    .RTC(RTC),
    .KEYSCANCODE(key_scancode),
    .KEYSCANCODE_ACK(key_scancode_ack),
    .KEYSCANCODE_CLR(key_scancode_clr),
    .RD(wait_start_gluclock & ~rd_n),
    .WR(wait_start_gluclock & ~wr_n),
    .A(wait_addr),
    .DI(d),
    .DO(wait_read),
    .loader_WR(cmos_wr),
    .loader_A(cmos_addr),
    .loader_DI(cmos_do),
    .loader_DO(cmos_di)
  );


  // ZiFi
  wire [7:0] zifi_do;
  wire zifi_dataout;

  zifi zifi
  (
    .clk(fclk),
    .rst(rst),
    .din(d),
    .dout(zifi_do),
    .dataout(zifi_dataout),
    .a(a),
    .iord(iord),
    .iord_s(iord_s),
    .iowr_s(iowr_s),
    .rx(UART_RX),
    .tx(UART_TX)
  );


  // Soundrive
  wire [7:0] covox_a;
  wire [7:0] covox_b;
  wire [7:0] covox_c;
  wire [7:0] covox_d;

  soundrive soundrive
  (
    .reset(rst),
    .clk(fclk),
    .cs(1),
    .wr_n(wr_n),
    .a(a[7:0]),
    .di(d),
    .iorq_n(iorq_n),
    .dos(dos),
    .outa(covox_a),
    .outb(covox_b),
    .outc(covox_c),
    .outd(covox_d)
  );


  // Turbosound FM
  reg ce_ym;
  always @(posedge fclk) begin
    reg [2:0] div;

    div <= div + 1'd1;
    ce_ym <= !div;
  end

  wire ts_enable = ~iorq_n & a[0] & a[15] & ~a[1];
  wire ts_we     = ts_enable & ~wr_n;

  wire  [7:0] ts_psg_ch_a_0;
  wire  [7:0] ts_psg_ch_b_0;
  wire  [7:0] ts_psg_ch_c_0;
  wire signed [15:0] ts_opn_0;
  wire  [7:0] ts_psg_ch_a_1;
  wire  [7:0] ts_psg_ch_b_1;
  wire  [7:0] ts_psg_ch_c_1;
  wire signed [15:0] ts_opn_1;
  wire  [7:0] ts_do;
  wire  [7:0] ioa_0_out;
  wire  [7:0] ioa_1_out;
  reg ioa_0_out_2_r = 1'b0, ioa_1_out_2_r = 1'b0;
  always @(posedge fclk) begin
    if (ioa_0_out_2_r != ioa_0_out[2]) begin
      ioa_0_out_2_r <= ioa_0_out[2];
      MIDI_OUT <= ioa_0_out[2];
    end
    if (ioa_1_out_2_r != ioa_1_out[2]) begin
      ioa_1_out_2_r <= ioa_1_out[2];
      MIDI_OUT <= ioa_1_out[2];
    end
  end

  turbosound turbosound
  (
    .RESET(rst),
    .CLK(fclk),
    .CE(ce_ym),
    .BDIR(ts_we),
    .BC(a[14]),
    .DI(d),
    .DO(ts_do),
    .PSG_CH_A_0(ts_psg_ch_a_0),
    .PSG_CH_B_0(ts_psg_ch_b_0),
    .PSG_CH_C_0(ts_psg_ch_c_0),
    .OPN_0(ts_opn_0),
    .PSG_CH_A_1(ts_psg_ch_a_1),
    .PSG_CH_B_1(ts_psg_ch_b_1),
    .PSG_CH_C_1(ts_psg_ch_c_1),
    .OPN_1(ts_opn_1),
    .IOA_0_out(ioa_0_out),
    .IOA_1_out(ioa_1_out)
  );


  // General Sound
  wire [23:0] gs_dram_addr;
  wire  [1:0] gs_dram_bsel;
  wire [15:0] gs_dram_di;
  wire [15:0] gs_dram_do;
  wire        gs_dram_req;
  wire        gs_dram_rnw;
  wire        gs_dram_ack;

  wire signed [14:0] gs_a;
  wire signed [14:0] gs_b;
  wire signed [14:0] gs_c;
  wire signed [14:0] gs_d;
  wire [7:0]  gs_do_bus;
  wire        gs_sel = ~iorq_n & m1_n & (a[7:4] == 'hB && a[2:0] == 'h3);

  gs_top gs_top
  (
    .RESET(rst),
    .CLK(clk),
    .CE(ce),

    .A(a[3]),
    .DI(d),
    .DO(gs_do_bus),
    .CS_n(iorq_n | ~gs_sel),
    .WR_n(wr_n),
    .RD_n(rd_n),

    .DRAM_ADDR(gs_dram_addr),
    .DRAM_BSEL(gs_dram_bsel),
    .DRAM_DI(gs_dram_di),
    .DRAM_DO(gs_dram_do),
    .DRAM_REQ(gs_dram_req),
    .DRAM_RNW(gs_dram_rnw),
    .DRAM_ACK(gs_dram_ack),

    .OUT_A(gs_a),
    .OUT_B(gs_b),
    .OUT_C(gs_c),
    .OUT_D(gs_d),

    .ROM_INITING(loader_act && loader_cs_rom_gs)
  );


  // SAA1099
  wire [7:0]  saa_out_l;
  wire [7:0]  saa_out_r;
  wire        saa_wr_n = ~iorq_n && ~wr_n && a[7:0] == 8'hFF && ~dos;

  reg ce_saa;
  always @(posedge fclk) begin
    reg [2:0] div;
    div <= div + 1'd1;
    if(div == 6) div <= 0;
    ce_saa <= (div == 0 || div == 3);
  end

  saa1099 saa1099
  (
    .clk_sys(fclk),
    .ce(ce_saa),
    .rst_n(rst_n),
    .cs_n(0),
    .a0(a[8]),		// 0=data, 1=address
    .wr_n(saa_wr_n),
    .din(d),
    .out_l(saa_out_l),
    .out_r(saa_out_r)
  );


  // OPL3 ports #C4-#C7 (bank 0 address/data, bank 1 address/data)
  wire        opl_enable = iorq && (a[7:2] == 6'b110001);
  wire  [7:0] opl_do;
  wire signed [15:0] opl_l;
  wire signed [15:0] opl_r;

  opl3 opl3
  (
    .clk(fclk),
    .clk_host(fclk),
    .clk_dac(fclk),
    .ic_n(rst_n),
    .cs_n(~opl_enable),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .address(a[1:0]),
    .din(d),
    .dout(opl_do),
    .sample_l(opl_l),
    .sample_r(opl_r)
  );


  // Beeper
  reg [7:0] port_xxfe_reg;
  always @(posedge fclk) if (beeper_wr) port_xxfe_reg <= d;

  // Audio output
  mixer mixer
  (
    .CLK(fclk),
    .ACB(CFG_TURBOSOUND_ACB),
    .BOOST(CFG_AUDIO_BOOST),
    .PSG_CH_A_0(ts_psg_ch_a_0),
    .PSG_CH_B_0(ts_psg_ch_b_0),
    .PSG_CH_C_0(ts_psg_ch_c_0),
    .OPN_0(ts_opn_0),
    .PSG_CH_A_1(ts_psg_ch_a_1),
    .PSG_CH_B_1(ts_psg_ch_b_1),
    .PSG_CH_C_1(ts_psg_ch_c_1),
    .OPN_1(ts_opn_1),
    .GS_A(gs_a),
    .GS_B(gs_b),
    .GS_C(gs_c),
    .GS_D(gs_d),
    .COVOX_A(covox_a),
    .COVOX_B(covox_b),
    .COVOX_C(covox_c),
    .COVOX_D(covox_d),
    .SAA_L(saa_out_l),
    .SAA_R(saa_out_r),
    .OPL_L(opl_l),
    .OPL_R(opl_r),
    .BEEPER(port_xxfe_reg[4]),
    .TAPE_OUT(port_xxfe_reg[3]),
    .TAPE_IN(TAPE_IN),
    .SOUND_L(SOUND_L),
    .SOUND_R(SOUND_R)
  );


  // CPU interface
  assign di =
      (~mreq_n && ~rd_n)                  ? dout_ram      : // SDRAM
      (gs_sel && ~rd_n)                   ? gs_do_bus     : // General Sound
      (ts_enable && ~rd_n)                ? ts_do         : // TurboSound
      (opl_enable && ~rd_n)               ? opl_do        : // OPL status
      (zifi_dataout && ~rd_n)             ? zifi_do       : // ZiFi
      (ena_ports)                         ? dout_ports    :
      (intack)                            ? im2vect       :
                                            8'b11111111;

endmodule
