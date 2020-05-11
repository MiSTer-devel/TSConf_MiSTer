
// PentEvo project (c) NedoPC 2008-2010

module zports
(
	input            clk,

	input      [7:0] din,
	output reg [7:0] dout,
	output           dataout,
	input     [15:0] a,

	input            rst,     // system reset
	input            opfetch,

	input            rd,
	input            wr,
	input            rdwr,

	input            iorq,
	input            iorq_s,
	input            iord,
	input            iord_s,
	input            iowr,
	input            iowr_s,
	input            iordwr,
	input            iordwr_s,

	output           porthit,       // when internal port hit occurs, this is 1, else 0; used for iorq1_n iorq2_n on zxbus
	output           external_port, // asserts for AY and VG93 accesses

	output           zborder_wr,
	output           border_wr,
	output           zvpage_wr,
	output           vpage_wr,
	output           vconf_wr,
	output           gx_offsl_wr,
	output           gx_offsh_wr,
	output           gy_offsl_wr,
	output           gy_offsh_wr,
	output           t0x_offsl_wr,
	output           t0x_offsh_wr,
	output           t0y_offsl_wr,
	output           t0y_offsh_wr,
	output           t1x_offsl_wr,
	output           t1x_offsh_wr,
	output           t1y_offsl_wr,
	output           t1y_offsh_wr,
	output           tsconf_wr,
	output           palsel_wr,
	output           tmpage_wr,
	output           t0gpage_wr,
	output           t1gpage_wr,
	output           sgpage_wr,
	output           hint_beg_wr ,
	output           vint_begl_wr,
	output           vint_begh_wr,

	output    [31:0] xt_page,

	output reg [4:0] fmaddr,
	input            regs_we,

	output reg [7:0] sysconf,
	output reg [7:0] memconf,
	output reg [3:0] cacheconf,
	output reg [7:0] fddvirt,

	output     [8:0] dmaport_wr,
	input            dma_act,
	output reg [1:0] dmawpdev,


	output reg [7:0] intmask,

	input            dos,
	input            vdos,
	output           vdos_on,
	output           vdos_off,

	output           ay_bdir,
	output           ay_bc1,
	output           covox_wr,
	output           beeper_wr,

	input            tape_read,

	input      [4:0] keys_in, // keys (port FE)
	input      [7:0] mus_in,  // mouse (xxDF)
	input      [5:0] kj_in,

	input            vg_intrq,
	input            vg_drq,  // from vg93 module - drq + irq read
	output           vg_cs_n,
	output           vg_wrFF,
	output    [1:0]  drive_sel,    // disk drive selection

	// SPI
	output           sdcs_n,
	output           sd_start,
	output     [7:0] sd_datain,
	input      [7:0] sd_dataout,

	// WAIT-ports related
	output reg  [7:0] wait_addr,
	output            wait_start_gluclock, // begin wait from some ports
	output            wait_start_comport,  //
	output reg  [7:0] wait_write,
	input       [7:0] wait_read
);

assign sdcs_n = spi_cs_n[0];

localparam FDR_VER = 1'b0;

localparam VDAC_VER = 3'h3;

localparam PORTFE = 8'hFE;
localparam PORTFD = 8'hFD;
localparam PORTXT = 8'hAF;
localparam PORTF7 = 8'hF7;
localparam COVOX  = 8'hFB;

localparam VGCOM  = 8'h1F;
localparam VGTRK  = 8'h3F;
localparam VGSEC  = 8'h5F;
localparam VGDAT  = 8'h7F;
localparam VGSYS  = 8'hFF;

localparam KJOY   = 8'h1F;
localparam KMOUSE = 8'hDF;

localparam SDCFG  = 8'h77;
localparam SDDAT  = 8'h57;

localparam COMPORT = 8'hEF;     // F8EF..FFEF - rs232 ports


wire [7:0] loa = a[7:0];
wire [7:0] hoa = regs_we ? a[7:0] : a[15:8];

assign porthit =	((loa==PORTFE) || (loa==PORTXT) || (loa==PORTFD) || (loa==COVOX))
					|| ((loa==PORTF7) && !dos)
					|| ((vg_port || vgsys_port) && (dos || open_vg))
					|| ((loa==KJOY) && !dos && !open_vg)
					|| (loa==KMOUSE)
					|| (((loa==SDCFG) || (loa==SDDAT)) && (!dos || vdos))
					|| (loa==COMPORT);

wire vg_port = (loa==VGCOM) || (loa==VGTRK) || (loa==VGSEC) || (loa==VGDAT);
wire vgsys_port = (loa==VGSYS);

assign external_port = ((loa==PORTFD) && a[15])        // AY
                    || (((loa==VGCOM) || (loa==VGTRK) || (loa==VGSEC) || (loa==VGDAT)) && (dos || open_vg));

assign dataout = porthit && iord && (~external_port);


reg iowr_reg;
reg iord_reg;
reg port_wr;
reg port_rd;

always @(posedge clk) begin
	iowr_reg <= iowr;
	port_wr <= (!iowr_reg && iowr);

	iord_reg <= iord;
	port_rd <= (!iord_reg && iord);
end


// reading ports
always @(*) begin
	case (loa)
		PORTFE:
			dout = {1'b1, tape_read, 1'b0, keys_in};

		PORTXT:
			begin
				case (hoa)
					XSTAT:
						dout = {1'b0, pwr_up_reg, FDR_VER, 2'b0, VDAC_VER};

					DMASTAT:
						dout = {dma_act, 7'b0};

					RAMPAGE + 8'd2, RAMPAGE + 8'd3:
						dout = rampage[hoa[1:0]];

				default:
					dout = 8'hFF;

				endcase
			end

		VGSYS:
			dout = {vg_intrq, vg_drq, 6'b111111};

		KJOY:
			dout = {2'b00, kj_in};
		KMOUSE:
			dout = mus_in;

		SDCFG:
			dout = 8'h00; // always SD inserted, SD is in R/W mode
		SDDAT:
			dout = sd_dataout;

		PORTF7:
			begin
				if (!a[14] && (a[8] ^ dos) && gluclock_on) dout = wait_read; // $BFF7 - data i/o
				else dout = 8'hFF; // any other $xxF7 port
			end

		COMPORT:
			dout = wait_read; // $F8EF..$FFEF

		default:
			dout = 8'hFF;
	endcase
end


// power-up
// This bit is loaded as 1 while FPGA is configured
// and automatically reset to 0 after STATUS port reading
reg pwr_up_reg;
reg pwr_up = 1;
always @(posedge clk) begin
	if (iord_s & (loa == PORTXT) & (hoa == XSTAT)) begin
		pwr_up_reg <= pwr_up;
		pwr_up <= 1'b0;
	end
end

// writing ports

//#nnAF
localparam VCONF    = 8'h00;
localparam VPAGE    = 8'h01;
localparam GXOFFSL    = 8'h02;
localparam GXOFFSH    = 8'h03;
localparam GYOFFSL    = 8'h04;
localparam GYOFFSH    = 8'h05;
localparam TSCONF    = 8'h06;
localparam PALSEL     = 8'h07;
localparam XBORDER    = 8'h0F;

localparam T0XOFFSL    = 8'h40;
localparam T0XOFFSH    = 8'h41;
localparam T0YOFFSL    = 8'h42;
localparam T0YOFFSH    = 8'h43;
localparam T1XOFFSL    = 8'h44;
localparam T1XOFFSH    = 8'h45;
localparam T1YOFFSL    = 8'h46;
localparam T1YOFFSH    = 8'h47;

localparam RAMPAGE   = 8'h10;  // this covers #10-#13
localparam FMADDR    = 8'h15;
localparam TMPAGE    = 8'h16;
localparam T0GPAGE   = 8'h17;
localparam T1GPAGE   = 8'h18;
localparam SGPAGE    = 8'h19;
localparam DMASADDRL = 8'h1A;
localparam DMASADDRH = 8'h1B;
localparam DMASADDRX = 8'h1C;
localparam DMADADDRL = 8'h1D;
localparam DMADADDRH = 8'h1E;
localparam DMADADDRX = 8'h1F;

localparam SYSCONF   = 8'h20;
localparam MEMCONF   = 8'h21;
localparam HSINT     = 8'h22;
localparam VSINTL    = 8'h23;
localparam VSINTH    = 8'h24;
localparam DMAWPD    = 8'h25;
localparam DMALEN    = 8'h26;
localparam DMACTRL   = 8'h27;
localparam DMANUM    = 8'h28;
localparam FDDVIRT   = 8'h29;
localparam INTMASK   = 8'h2A;
localparam CACHECONF = 8'h2B;
localparam DMAWPA    = 8'h2D;

localparam XSTAT     = 8'h00;
localparam DMASTAT   = 8'h27;

assign dmaport_wr[0] = portxt_wr && (hoa == DMASADDRL);
assign dmaport_wr[1] = portxt_wr && (hoa == DMASADDRH);
assign dmaport_wr[2] = portxt_wr && (hoa == DMASADDRX);
assign dmaport_wr[3] = portxt_wr && (hoa == DMADADDRL);
assign dmaport_wr[4] = portxt_wr && (hoa == DMADADDRH);
assign dmaport_wr[5] = portxt_wr && (hoa == DMADADDRX);
assign dmaport_wr[6] = portxt_wr && (hoa == DMALEN);
assign dmaport_wr[7] = portxt_wr && (hoa == DMACTRL);
assign dmaport_wr[8] = portxt_wr && (hoa == DMANUM);

assign zborder_wr    = portfe_wr;
assign border_wr     = (portxt_wr && (hoa == XBORDER));
assign zvpage_wr     = p7ffd_wr;
assign vpage_wr      = (portxt_wr && (hoa == VPAGE ));
assign vconf_wr      = (portxt_wr && (hoa == VCONF ));
assign gx_offsl_wr   = (portxt_wr && (hoa == GXOFFSL));
assign gx_offsh_wr   = (portxt_wr && (hoa == GXOFFSH));
assign gy_offsl_wr   = (portxt_wr && (hoa == GYOFFSL));
assign gy_offsh_wr   = (portxt_wr && (hoa == GYOFFSH));
assign t0x_offsl_wr  = (portxt_wr && (hoa == T0XOFFSL));
assign t0x_offsh_wr  = (portxt_wr && (hoa == T0XOFFSH));
assign t0y_offsl_wr  = (portxt_wr && (hoa == T0YOFFSL));
assign t0y_offsh_wr  = (portxt_wr && (hoa == T0YOFFSH));
assign t1x_offsl_wr  = (portxt_wr && (hoa == T1XOFFSL));
assign t1x_offsh_wr  = (portxt_wr && (hoa == T1XOFFSH));
assign t1y_offsl_wr  = (portxt_wr && (hoa == T1YOFFSL));
assign t1y_offsh_wr  = (portxt_wr && (hoa == T1YOFFSH));
assign tsconf_wr     = (portxt_wr && (hoa == TSCONF));
assign palsel_wr     = (portxt_wr && (hoa == PALSEL));
assign tmpage_wr     = (portxt_wr && (hoa == TMPAGE));
assign t0gpage_wr    = (portxt_wr && (hoa == T0GPAGE));
assign t1gpage_wr    = (portxt_wr && (hoa == T1GPAGE));
assign sgpage_wr     = (portxt_wr && (hoa == SGPAGE));
assign hint_beg_wr   = (portxt_wr && (hoa == HSINT ));
assign vint_begl_wr  = (portxt_wr && (hoa == VSINTL));
assign vint_begh_wr  = (portxt_wr && (hoa == VSINTH));

assign beeper_wr = portfe_wr;
wire portfe_wr = (loa==PORTFE) && iowr_s;
assign covox_wr = (loa==COVOX) && iowr_s;
wire portxt_wr = ((loa==PORTXT) && iowr_s) || regs_we;

reg [7:0] rampage[0:3];
assign xt_page = {rampage[3], rampage[2], rampage[1], rampage[0]};

wire lock128 = lock128_3 ? 1'b0 : (lock128_2 ? m1_lock128 : memconf[6]);
wire lock128_2 = memconf[7:6] == 2'b10;    // mode 2
wire lock128_3 = memconf[7:6] == 2'b11;     // mode 3

reg m1_lock128;
always @(posedge clk) if (opfetch) m1_lock128 <= !(din[7] ^ din[6]);

always @(posedge clk) begin
	if (rst) begin
		fmaddr[4] <= 1'b0;
		intmask   <= 8'b1;
		fddvirt   <= 8'b0;
		sysconf   <= 8'h00;  // 3.5 MHz
		memconf   <= 8'h04;  // no map
		cacheconf <= 4'h0;   // no cache

		rampage[0]<= 8'h00;
		rampage[1]<= 8'h05;
		rampage[2]<= 8'h02;
		rampage[3]<= 8'h00;
	end
	else if (p7ffd_wr) begin
		memconf[0] <= din[4];
		rampage[3] <= {2'b0, lock128_3 ? {din[5], din[7:6]} : ({1'b0, lock128 ? 2'b0 : din[7:6]}), din[2:0]};
	end
   else if (portxt_wr) begin
		if (hoa[7:2] == RAMPAGE[7:2]) rampage[hoa[1:0]] <= din;

		if (hoa == FMADDR) fmaddr <= din[4:0];

		if (hoa == SYSCONF) begin
			sysconf <= din;
			cacheconf <= {4{din[2]}};
		end

		if (hoa == DMAWPD)    dmawpdev  <= din[1:0];
		if (hoa == CACHECONF) cacheconf <= din[3:0];
		if (hoa == MEMCONF)   memconf   <= din;
		if (hoa == FDDVIRT)   fddvirt   <= din;
		if (hoa == INTMASK)   intmask   <= din;
	end
end

// 7FFD port
wire p7ffd_wr = !a[15] && (loa==PORTFD) && iowr_s && !lock48;

reg lock48;
always @(posedge clk) begin
	if (rst) lock48 <= 1'b0;
	else if (p7ffd_wr && !lock128_3) lock48 <= din[5];
end

// AY control
wire ay_hit = (loa==PORTFD) & a[15];
assign ay_bc1  = ay_hit & a[14] & iordwr;
assign ay_bdir = ay_hit & iowr;

// VG93
wire [3:0] fddvrt = fddvirt[3:0];
wire virt_vg = fddvrt[drive_sel_raw];
wire open_vg = fddvirt[7];
assign drive_sel = {drive_sel_raw[1], drive_sel_raw[0]};

wire vg_wen = (dos || open_vg) && !vdos && !virt_vg;
assign vg_cs_n = !(iordwr && vg_port && vg_wen);
assign vg_wrFF = iowr_s && vgsys_port && vg_wen;
wire vg_wrDS = iowr_s && vgsys_port && (dos || open_vg);

assign vdos_on  = iordwr_s && (vg_port || vgsys_port) && dos && !vdos && virt_vg;
assign vdos_off = iordwr_s && vg_port && vdos;

// write drive number
reg [1:0] drive_sel_raw;
always @(posedge clk) if (vg_wrDS) drive_sel_raw <= din[1:0];

// SD card (Z-controller compatible)
wire sdcfg_wr;
wire sddat_wr;
wire sddat_rd;
reg [1:0] spi_cs_n;

assign sdcfg_wr = ((loa==SDCFG) && iowr_s && (!dos || vdos));
assign sddat_wr = ((loa==SDDAT) && iowr_s && (!dos || vdos));
assign sddat_rd = ((loa==SDDAT) && iord_s);

// SDCFG write - sdcs_n control
always @(posedge clk) begin
	if (rst) spi_cs_n <= 2'b11;
	else if (sdcfg_wr) spi_cs_n <= {~din[2], din[1]};
end

// start signal for SPI module with resyncing to fclk
assign sd_start = sddat_wr || sddat_rd;

// data for SPI module
assign sd_datain = wr ? din : 8'hFF;

// xxF7
wire portf7_wr = ((loa==PORTF7) && (a[8]==1'b1) && port_wr && (!dos || vdos));
wire portf7_rd = ((loa==PORTF7) && (a[8]==1'b1) && port_rd && (!dos || vdos));

// EFF7 port
reg [7:0] peff7;
always @(posedge clk) begin
	if (rst) peff7 <= 8'h00;
	else if (!a[12] && portf7_wr && !dos) peff7 <= din;  // #EEF7 in dos is not accessible
end

// gluclock ports
wire gluclock_on = peff7[7] || dos;        // in dos mode EEF7 is not accessible, gluclock access is ON in dos mode.

// comports
wire comport_wr   = ((loa == COMPORT) && port_wr);
wire comport_rd   = ((loa == COMPORT) && port_rd);

// write to wait registers
always @(posedge clk) begin
	// gluclocks
	if (gluclock_on && portf7_wr) begin
		if (!a[14]) wait_write <= din; // $BFF7 - data reg
		if (!a[13]) wait_addr <= din; // $DFF7 - addr reg
	end

	// com ports
	if (comport_wr) wait_write <= din; // $xxEF
	if (comport_wr || comport_rd) wait_addr <= a[15:8];
	
	if ((loa==PORTXT) && (hoa == DMAWPA)) wait_addr <= din;
end
  
// wait from wait registers
// ACHTUNG!!!! here portxx_wr are ON Z80 CLOCK! logic must change when moving to clk strobes
assign wait_start_gluclock = (gluclock_on && !a[14] && (portf7_rd || portf7_wr)); // $BFF7 - gluclock r/w
assign wait_start_comport = (comport_rd || comport_wr);

endmodule
