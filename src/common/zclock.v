
// PentEvo project (c) NedoPC 2008-2011
//
// Z80 clocking module, also contains some wait-stating when 14MHz
//
// IDEAL:
// clk    _/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\_/`\
//          |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// zclk     /```\___/```\___/```\___/```````\_______/```````\_______/```````````````\_______________/```````````````\_______________/`
//          |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// zpos     `\___/```\___/```\___/```\___________/```\___________/```\___________________________/```\___________________________/```\
//          |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// zneg     _/```\___/```\___/```\_______/```\___________/```\___________________/```\___________________________/```\________________

// clock phasing:
// c3 must be zpos for 7mhz, therefore c1 - zneg
// for 3.5 mhz, c3 is both zpos and zneg (alternating)


// 14MHz rulez:
// 1. do variable stalls for memory access.
// 2. do fallback on 7mhz for external IO accesses
// 3. clock switch 14-7-3.5 only at RFSH

module zclock
(
	input       clk,
	output      zclk_out,
	input       c0, c2, f0, f1,

	input       iorq_s,
	input       external_port,

	output reg  zpos,
	output reg  zneg,

	// stall enables and triggers
	input       cpu_stall,
	input       ide_stall,
	input       dos_on,
	input       vdos_off,

	input [1:0] turbo  // 2'b00 -  3.5 MHz
							 // 2'b01 -  7.0 MHz
							 // 2'b1x - 14.0 MHz
);

assign zclk_out = ~zclk_o;
reg zclk_o;

wire [1:0] turbo_int = turbo;

// wait generator
wire dos_io_stall = stall_start || !stall_count_end;
wire stall_start = dos_stall || io_stall;
wire dos_stall = dos_on || vdos_off;
wire io_stall = iorq_s && external_port && turbo_int[1];
wire stall_count_end = stall_count[3];

reg [3:0] stall_count;
always @(posedge clk) begin
	if (stall_start) begin
		if (dos_stall)     stall_count <= 4;  // 4 tacts 28MHz (1 tact 7MHz)
		else if (io_stall) stall_count <= 0;  // 8 tacts 28MHz (1 tact 3.5MHz)
	end
	else if (!stall_count_end) stall_count <= stall_count + 3'd1;
end

// Z80 clocking pre-strobes
wire pre_zpos = turbo_int[1] ? pre_zpos_140 : (turbo_int[0] ? pre_zpos_70 : pre_zpos_35);
wire pre_zneg = turbo_int[1] ? pre_zneg_140 : (turbo_int[0] ? pre_zneg_70 : pre_zneg_35);

wire pre_zpos_140 = f1;
wire pre_zneg_140 = f0;

wire pre_zpos_70 = c2;
wire pre_zneg_70 = c0;

wire pre_zpos_35 =  c2_cnt && c2;
wire pre_zneg_35 = !c2_cnt && c2;

reg c2_cnt;
always @(posedge clk) if (c2) c2_cnt <= ~c2_cnt;


// Z80 clocking strobes
wire stall = cpu_stall || dos_io_stall || ide_stall;

always @(posedge clk) begin
	zpos <= !stall && pre_zpos && zclk_o;
	zneg <= !stall && pre_zneg && !zclk_o;
end

// make Z80 clock: account for external inversion and make some leading of clock
// 9.5 ns propagation delay: from clk posedge to zclk returned back any edge
// (1/28)/2=17.9ns half a clock lead
// 2.6ns lag because of non-output register emitting of zclk_o
// total: 5.8 ns lead of any edge of zclk relative to posedge of clk => ACCOUNT FOR THIS WHEN DOING INTER-CLOCK DATA TRANSFERS

// Z80 clocking
always @(negedge clk) begin
	if (zpos) zclk_o <= 0;
	if (zneg) zclk_o <= 1;
end

endmodule
